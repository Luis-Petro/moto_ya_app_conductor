import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/billetera_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../domain/models/billetera.dart';
import '../../core/tab_activa.dart';

/// Estado de la billetera: deuda/saldo a favor, límite, bloqueo y pago con
/// Nequi/Bre-B. REST es la fuente de verdad (design D7); tras iniciar el pago
/// se reconcilia releyendo el saldo (design D8: confirmación por webhook).
class BilleteraViewModel extends ChangeNotifier {
  BilleteraViewModel(this._billetera, this._conductores, this._tab) {
    _tab.addListener(_onTabActiva);
  }

  final BilleteraRepository _billetera;
  final ConductorRepository _conductores;
  final TabActiva _tab;

  bool cargando = true;
  bool pagando = false;
  String? error;
  String? aviso;
  Billetera? billetera;

  /// Datos de destino (Nequi/Bre-B) a donde transferir, administrados por el panel.
  DatosPago? datosPago;

  MedioPago medioSeleccionado = MedioPago.nequi;

  /// Instrucciones de la última intención iniciada en esta sesión (referencia,
  /// enlace, texto del proveedor). Solo vive en memoria: es lo único que el
  /// servidor no vuelve a dar al releer los pagos.
  IntencionPago? intencion;

  /// Pagos del conductor tal como los conoce el backend. De aquí sale el pago
  /// pendiente y el historial: antes el "pago en proceso" era estado en memoria
  /// de la pantalla y se perdía al cambiar de pestaña o reabrir la app.
  List<PagoRealizado> pagos = const [];

  /// El pago que aún está en revisión (el más reciente pendiente), si lo hay.
  PagoRealizado? get pagoPendiente {
    for (final p in pagos) {
      if (p.pendiente) return p;
    }
    return null;
  }

  /// Id del pago que estamos vigilando para avisar cuando se confirme.
  int? _vigilandoPagoId;

  /// Estado de bloqueo al iniciar el último pago: para redactar el aviso de
  /// confirmación ("tu cuenta se reactivó" vs. "tu saldo se actualizó").
  bool _bloqueadoAlPagar = false;

  /// Sondeo del saldo mientras hay un pago pendiente y el tab está visible: el
  /// backend confirma el pago de forma asíncrona (webhook/conciliación admin) y
  /// no empuja evento, así que refrescamos para reflejarlo casi en tiempo real.
  Timer? _poll;
  static const Duration _intervaloPoll = Duration(seconds: 8);
  bool _disposed = false;

  bool get bloqueado => billetera?.bloqueado ?? false;

  /// Refresco silencioso al volver a este tab (saldo al día tras entregar un
  /// pedido, sin parpadear el spinner) y gestión del sondeo del pago.
  void _onTabActiva() {
    if (_tab.indice == TabActiva.billetera) {
      _cargar(silencioso: true);
      _sincronizarPoll();
    } else {
      _poll?.cancel();
    }
  }

  /// Activa el sondeo solo cuando hace falta: tab visible y pago pendiente.
  void _sincronizarPoll() {
    final debeSondear =
        _tab.indice == TabActiva.billetera && pagoPendiente != null;
    if (debeSondear) {
      _poll ??= Timer.periodic(_intervaloPoll, (_) => _cargar(silencioso: true));
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> cargar() => _cargar();

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      cargando = true;
      error = null;
      notifyListeners();
    }
    final res = await _billetera.saldo(forzar: true);
    res.when(ok: (b) => billetera = b, err: (f) => error = f.message);
    final resPagos = await _billetera.pagos();
    pagos = resPagos.valueOrNull ?? pagos;
    _resolverPagoVigilado();
    cargando = false;
    if (!_disposed) notifyListeners();
    // Datos de destino: se cargan una vez (no bloquean el render del saldo).
    if (datosPago == null) {
      final d = await _billetera.datosPago();
      datosPago = d.valueOrNull ?? datosPago;
      if (!_disposed) notifyListeners();
    }
  }

  /// Avisa cuando el pago que estábamos vigilando deja de estar pendiente en el
  /// servidor. La confirmación la decide el backend (webhook o conciliación del
  /// admin); la app ya no la infiere restando la deuda.
  void _resolverPagoVigilado() {
    final id = _vigilandoPagoId;
    if (id == null) return;
    PagoRealizado? p;
    for (final x in pagos) {
      if (x.id == id) p = x;
    }
    if (p == null || p.pendiente) return;
    _vigilandoPagoId = null;
    if (p.confirmado) {
      final reactivado = _bloqueadoAlPagar && !(billetera?.bloqueado ?? false);
      aviso = reactivado
          ? 'Pago confirmado. Tu cuenta se reactivó: ya puedes recibir pedidos.'
          : 'Pago confirmado. Tu saldo se actualizó.';
      // Al reactivarse, refresca el perfil del conductor para que el gating de
      // "En línea" (Inicio) se desbloquee de inmediato, sin esperar al tab.
      if (reactivado) _conductores.cargar(forzar: true);
    } else {
      aviso = 'El pago no se pudo confirmar. Revisa los datos e inténtalo de nuevo.';
    }
    _sincronizarPoll();
  }

  /// Descarta el aviso y las instrucciones del último pago iniciado. No borra
  /// el pago: si sigue pendiente, se sigue viendo (viene del servidor).
  void descartarIntencion() {
    intencion = null;
    aviso = null;
    _sincronizarPoll();
    notifyListeners();
  }

  void seleccionarMedio(MedioPago medio) {
    medioSeleccionado = medio;
    notifyListeners();
  }

  /// Inicia un pago/abono por [monto] (puede superar la deuda: el excedente
  /// queda como saldo a favor). La confirmación real llega por webhook; aquí
  /// solo se refleja el estado "pendiente" y se reconcilia.
  Future<bool> pagar(double monto, {String? titularOrigen}) async {
    if (monto <= 0) {
      error = 'Ingresa un monto válido';
      notifyListeners();
      return false;
    }
    pagando = true;
    error = null;
    aviso = null;
    notifyListeners();
    final res = await _billetera.pagar(
      medioPago: medioSeleccionado,
      monto: monto,
      titularOrigen: titularOrigen,
    );
    final ok = res.isSuccess;
    if (ok) {
      _bloqueadoAlPagar = bloqueado;
      // Completar la intención con lo que la app ya sabe (el backend devuelve
      // referencia/instrucciones, no monto ni medio).
      final i = res.valueOrNull;
      _vigilandoPagoId = i?.pagoId;
      intencion = IntencionPago(
        pagoId: i?.pagoId ?? 0,
        medioPago: medioSeleccionado,
        monto: monto,
        estado: i?.estado ?? 'PENDIENTE',
        referenciaExterna: i?.referenciaExterna,
        urlPago: i?.urlPago,
        instrucciones: i?.instrucciones,
      );
      aviso =
          'Pago iniciado con ${medioSeleccionado.label}. Confirmaremos y actualizaremos tu saldo al recibirlo.';
      // Reconciliar: releer saldo y pagos, y refrescar el estado del conductor.
      await _reconciliar();
      _sincronizarPoll();
    } else {
      error = res.when(ok: (_) => null, err: (f) => f.message);
    }
    pagando = false;
    notifyListeners();
    return ok;
  }

  Future<void> _reconciliar() async {
    final res = await _billetera.saldo(forzar: true);
    billetera = res.valueOrNull ?? billetera;
    final resPagos = await _billetera.pagos();
    pagos = resPagos.valueOrNull ?? pagos;
    _resolverPagoVigilado();
    await _conductores.cargar(forzar: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _tab.removeListener(_onTabActiva);
    super.dispose();
  }
}

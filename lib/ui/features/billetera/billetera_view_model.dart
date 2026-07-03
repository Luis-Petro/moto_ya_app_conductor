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

  MedioPago medioSeleccionado = MedioPago.nequi;

  /// Última intención de pago iniciada (info de la transacción: referencia,
  /// estado, instrucciones). Pasa a CONFIRMADO cuando el sondeo detecta que el
  /// pago ya se aplicó; se limpia al descartar el aviso.
  IntencionPago? intencion;

  /// Deuda y estado de bloqueo al iniciar el último pago: referencia para
  /// detectar que el pago se aplicó (deuda bajó / cuenta reactivada).
  double? _deudaAlPagar;
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
        _tab.indice == TabActiva.billetera && (intencion?.pendiente ?? false);
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
    _resolverPagoPendiente();
    cargando = false;
    if (!_disposed) notifyListeners();
  }

  /// Marca la intención como confirmada cuando el saldo refleja que el pago se
  /// aplicó: la deuda bajó al menos el monto pagado, o la cuenta se reactivó
  /// (bloqueada → al día). Detiene el sondeo al confirmar.
  void _resolverPagoPendiente() {
    final i = intencion;
    final b = billetera;
    if (i == null || !i.pendiente || b == null || _deudaAlPagar == null) return;
    final deudaBajo = b.deudaActual <= _deudaAlPagar! - i.monto + 1;
    final reactivado = _bloqueadoAlPagar && !b.bloqueado;
    if (deudaBajo || reactivado) {
      intencion = i.copyWith(estado: 'CONFIRMADO');
      aviso = reactivado
          ? 'Pago confirmado. Tu cuenta se reactivó: ya puedes recibir pedidos.'
          : 'Pago confirmado. Tu saldo se actualizó.';
      // Al reactivarse, refresca el perfil del conductor para que el gating de
      // "En línea" (Inicio) se desbloquee de inmediato, sin esperar al tab.
      if (reactivado) _conductores.cargar(forzar: true);
      _sincronizarPoll();
    }
  }

  /// Descarta el aviso de pago (pendiente o confirmado) del panel.
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
  Future<bool> pagar(double monto) async {
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
    );
    final ok = res.isSuccess;
    if (ok) {
      // Referencia de saldo previa al pago, para detectar luego que se aplicó.
      _deudaAlPagar = billetera?.deudaActual;
      _bloqueadoAlPagar = bloqueado;
      // Completar la intención con lo que la app ya sabe (el backend devuelve
      // referencia/instrucciones, no monto ni medio).
      final i = res.valueOrNull;
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
      // Reconciliar: releer saldo y refrescar el estado del conductor (gating).
      await _reconciliar();
      _resolverPagoPendiente();
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

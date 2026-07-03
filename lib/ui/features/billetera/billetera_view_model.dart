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
  /// estado, instrucciones). Se limpia al recargar con el pago ya confirmado.
  IntencionPago? intencion;

  bool get bloqueado => billetera?.bloqueado ?? false;

  /// Refresco silencioso al volver a este tab (saldo al día tras entregar un
  /// pedido, sin parpadear el spinner).
  void _onTabActiva() {
    if (_tab.indice == TabActiva.billetera) _cargar(silencioso: true);
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
    cargando = false;
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
    _tab.removeListener(_onTabActiva);
    super.dispose();
  }
}

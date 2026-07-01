import 'package:flutter/foundation.dart';

import '../../../data/repositories/billetera_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../domain/models/billetera.dart';

/// Estado de la billetera: deuda, límite, bloqueo y pago con Nequi/Bre-B.
/// REST es la fuente de verdad (design D7); tras iniciar el pago se reconcilia
/// releyendo el saldo (design D8: confirmación asíncrona por webhook).
class BilleteraViewModel extends ChangeNotifier {
  BilleteraViewModel(this._billetera, this._conductores);

  final BilleteraRepository _billetera;
  final ConductorRepository _conductores;

  bool cargando = true;
  bool pagando = false;
  String? error;
  String? aviso;
  Billetera? billetera;

  MedioPago medioSeleccionado = MedioPago.nequi;

  bool get bloqueado => billetera?.bloqueado ?? false;

  Future<void> cargar() async {
    cargando = true;
    error = null;
    notifyListeners();
    final res = await _billetera.saldo(forzar: true);
    res.when(ok: (b) => billetera = b, err: (f) => error = f.message);
    cargando = false;
    notifyListeners();
  }

  void seleccionarMedio(MedioPago medio) {
    medioSeleccionado = medio;
    notifyListeners();
  }

  /// Inicia el pago del total de la deuda. La confirmación real llega por
  /// webhook; aquí solo se refleja el estado "pendiente" y se reconcilia.
  Future<bool> pagarDeuda() async {
    final b = billetera;
    if (b == null || b.deudaActual <= 0) return false;
    pagando = true;
    error = null;
    aviso = null;
    notifyListeners();
    final res = await _billetera.pagar(
      medioPago: medioSeleccionado,
      monto: b.deudaActual,
    );
    final ok = res.isSuccess;
    if (ok) {
      aviso =
          'Pago iniciado con ${medioSeleccionado.label}. Confirmaremos y reactivaremos tu cuenta al recibirlo.';
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
}

import '../../domain/models/billetera.dart';
import '../services/api_result.dart';
import '../services/billetera_service.dart';

/// Fuente de verdad de la billetera del conductor.
class BilleteraRepository {
  BilleteraRepository(this._service);

  final BilleteraService _service;

  Billetera? _cache;
  Billetera? get enCache => _cache;

  Future<Result<Billetera>> saldo({bool forzar = true}) async {
    if (_cache != null && !forzar) return Ok(_cache!);
    final res = await _service.saldo();
    if (res case Ok<Billetera>(value: final b)) {
      _cache = b;
    }
    return res;
  }

  Future<Result<IntencionPago>> pagar({
    required MedioPago medioPago,
    required double monto,
  }) {
    return _service.pagar(medioPago: medioPago, monto: monto);
  }

  void limpiar() => _cache = null;
}

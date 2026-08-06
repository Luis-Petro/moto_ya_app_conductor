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
    String? cuentaOrigen,
    String? titularOrigen,
    String? entidadOrigen,
  }) {
    return _service.pagar(
      medioPago: medioPago,
      monto: monto,
      cuentaOrigen: cuentaOrigen,
      titularOrigen: titularOrigen,
      entidadOrigen: entidadOrigen,
    );
  }

  /// Datos de destino (Nequi/Bre-B) configurados por la plataforma.
  Future<Result<DatosPago>> datosPago() => _service.datosPago();

  /// Pagos del conductor (recientes primero). Sin caché: el pago pendiente se
  /// deriva de aquí y debe reflejar lo que el servidor sabe ahora mismo.
  Future<Result<List<PagoRealizado>>> pagos({int page = 0, int size = 20}) =>
      _service.pagos(page: page, size: size);

  void limpiar() => _cache = null;
}

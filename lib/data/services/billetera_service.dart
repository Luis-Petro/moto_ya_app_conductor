import '../../domain/models/billetera.dart';
import '../models/api_mappers.dart';
import 'api_client.dart';
import 'api_result.dart';

/// Cliente de la billetera del conductor (`/billetera/*`).
class BilleteraService {
  BilleteraService(this._api);

  final ApiClient _api;

  /// Saldo/deuda de comisiones y estado de la cuenta.
  Future<Result<Billetera>> saldo() {
    return _api.get<Billetera>('/billetera/saldo', parse: ApiMappers.billetera);
  }

  /// Datos de destino (Nequi/Bre-B) a donde el conductor debe transferir.
  Future<Result<DatosPago>> datosPago() {
    return _api.get<DatosPago>('/billetera/datos-pago', parse: ApiMappers.datosPago);
  }

  /// Inicia el pago de la deuda con Nequi o Bre-B, declarando la cuenta de
  /// origen. La confirmación llega por webhook del proveedor (design D8).
  Future<Result<IntencionPago>> pagar({
    required MedioPago medioPago,
    required double monto,
    String? cuentaOrigen,
    String? titularOrigen,
    String? entidadOrigen,
  }) {
    return _api.post<IntencionPago>(
      '/billetera/pagar',
      body: {
        'medioPago': medioPago.wire,
        'monto': monto,
        if (cuentaOrigen != null && cuentaOrigen.isNotEmpty) 'cuentaOrigen': cuentaOrigen,
        if (titularOrigen != null && titularOrigen.isNotEmpty) 'titularOrigen': titularOrigen,
        if (entidadOrigen != null && entidadOrigen.isNotEmpty) 'entidadOrigen': entidadOrigen,
      },
      parse: ApiMappers.intencionPago,
    );
  }
}

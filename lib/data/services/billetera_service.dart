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

  /// Inicia el pago de la deuda con Nequi o Bre-B. Devuelve la intención de
  /// pago; la confirmación llega por webhook del proveedor (design D8).
  Future<Result<IntencionPago>> pagar({
    required MedioPago medioPago,
    required double monto,
  }) {
    return _api.post<IntencionPago>(
      '/billetera/pagar',
      body: {'medioPago': medioPago.wire, 'monto': monto},
      parse: ApiMappers.intencionPago,
    );
  }
}

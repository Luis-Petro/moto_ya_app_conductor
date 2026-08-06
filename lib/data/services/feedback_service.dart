import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_result.dart';

/// Cliente de `POST /feedback`: queja o sugerencia con captura opcional.
class FeedbackService {
  FeedbackService(this._api);

  final ApiClient _api;

  /// [tipo] es `QUEJA` o `SUGERENCIA` (los valores que espera el backend).
  Future<Result<void>> enviar({
    required String tipo,
    required String mensaje,
    int? pedidoId,
    MultipartFile? captura,
  }) {
    return _api.postMultipart<void>('/feedback', fields: {
      'tipo': tipo,
      'mensaje': mensaje,
      'pedidoId': pedidoId,
      'captura': captura,
    });
  }
}

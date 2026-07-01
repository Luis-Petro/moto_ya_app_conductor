import 'api_client.dart';
import 'api_result.dart';

/// Cliente de `/notificaciones/token` (alta/baja del token push FCM).
class NotificacionService {
  NotificacionService(this._api);

  final ApiClient _api;

  Future<Result<void>> registrarToken(String token, {String? plataforma}) {
    return _api.post<void>('/notificaciones/token',
        body: {'token': token, 'plataforma': plataforma});
  }

  Future<Result<void>> eliminarToken(String token) {
    return _api.delete<void>('/notificaciones/token/$token');
  }
}

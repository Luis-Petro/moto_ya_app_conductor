import '../../domain/models/rol.dart';
import '../../domain/models/sesion.dart';
import '../models/api_mappers.dart';
import 'api_client.dart';
import 'api_result.dart';

/// Cliente de los endpoints `/auth/*`. Cada canal devuelve una [Sesion] (JWT).
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<Result<Sesion>> register({
    required String nombre,
    String? telefono,
    String? email,
    required String password,
  }) {
    return _api.post<Sesion>(
      '/auth/register',
      body: {
        'nombre': nombre,
        'telefono': telefono,
        'email': email,
        'password': password,
        'rol': Rol.conductor.wire,
      },
      parse: ApiMappers.sesion,
    );
  }

  Future<Result<Sesion>> login({
    required String email,
    required String password,
  }) {
    return _api.post<Sesion>(
      '/auth/login',
      body: {'email': email, 'password': password},
      parse: ApiMappers.sesion,
    );
  }

  Future<Result<Sesion>> google(String idToken) {
    return _api.post<Sesion>(
      '/auth/google',
      body: {'idToken': idToken},
      parse: ApiMappers.sesion,
    );
  }

  Future<Result<void>> solicitarOtp(String telefono) {
    return _api.post<void>('/auth/otp/solicitar', body: {'telefono': telefono});
  }

  Future<Result<Sesion>> verificarOtp({
    required String telefono,
    required String codigo,
    String? nombre,
  }) {
    return _api.post<Sesion>(
      '/auth/otp/verificar',
      body: {
        'telefono': telefono,
        'codigo': codigo,
        'nombre': nombre,
        'rol': Rol.conductor.wire,
      },
      parse: ApiMappers.sesion,
    );
  }
}

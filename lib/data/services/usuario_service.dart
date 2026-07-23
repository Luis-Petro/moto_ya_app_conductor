import '../../domain/models/usuario.dart';
import '../models/api_mappers.dart';
import 'api_client.dart';
import 'api_result.dart';

/// Cliente de `/usuarios/me`.
class UsuarioService {
  UsuarioService(this._api);

  final ApiClient _api;

  Future<Result<Usuario>> obtenerPerfil() {
    return _api.get<Usuario>('/usuarios/me', parse: ApiMappers.usuario);
  }

  /// El correo NO se cambia aquí: pasa por el flujo verificado
  /// ([solicitarCambioEmail] + [verificarCambioEmail]).
  Future<Result<Usuario>> actualizarPerfil({
    String? nombre,
    String? telefono,
    int? municipioId,
  }) {
    return _api.put<Usuario>(
      '/usuarios/me',
      body: {
        'nombre': nombre,
        'telefono': telefono,
        'municipioId': municipioId,
      },
      parse: ApiMappers.usuario,
    );
  }

  /// Paso 1 del cambio de correo: envía un código al correo NUEVO.
  Future<Result<void>> solicitarCambioEmail(String email) {
    return _api.post<void>('/usuarios/me/email/solicitar', body: {'email': email});
  }

  /// Paso 2: confirma el código y aplica el correo nuevo.
  Future<Result<Usuario>> verificarCambioEmail(String codigo) {
    return _api.post<Usuario>('/usuarios/me/email/verificar',
        body: {'codigo': codigo}, parse: ApiMappers.usuario);
  }
}

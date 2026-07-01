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

  Future<Result<Usuario>> actualizarPerfil({
    String? nombre,
    String? email,
    String? telefono,
  }) {
    return _api.put<Usuario>(
      '/usuarios/me',
      body: {'nombre': nombre, 'email': email, 'telefono': telefono},
      parse: ApiMappers.usuario,
    );
  }
}

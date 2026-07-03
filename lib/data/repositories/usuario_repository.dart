import '../../domain/models/usuario.dart';
import '../services/api_result.dart';
import '../services/usuario_service.dart';

/// Fuente de verdad del perfil del usuario, con caché en memoria.
class UsuarioRepository {
  UsuarioRepository(this._service);

  final UsuarioService _service;
  Usuario? _cache;

  Usuario? get enCache => _cache;

  Future<Result<Usuario>> perfil({bool forzar = false}) async {
    if (_cache != null && !forzar) return Ok(_cache!);
    final res = await _service.obtenerPerfil();
    if (res case Ok<Usuario>(value: final u)) {
      _cache = u;
    }
    return res;
  }

  Future<Result<Usuario>> actualizar({
    String? nombre,
    String? email,
    String? telefono,
    int? municipioId,
  }) async {
    final res = await _service.actualizarPerfil(
        nombre: nombre, email: email, telefono: telefono, municipioId: municipioId);
    if (res case Ok<Usuario>(value: final u)) {
      _cache = u;
    }
    return res;
  }

  void limpiar() => _cache = null;
}

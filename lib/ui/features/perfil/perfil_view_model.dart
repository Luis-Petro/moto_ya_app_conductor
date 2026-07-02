import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../domain/models/conductor.dart';
import '../../../domain/models/usuario.dart';

/// Estado del Perfil del conductor: datos personales, vehículo/documentos y
/// cierre de sesión.
class PerfilViewModel extends ChangeNotifier {
  PerfilViewModel(this._usuarios, this._conductores, this._auth);

  final UsuarioRepository _usuarios;
  final ConductorRepository _conductores;
  final AuthRepository _auth;

  bool cargando = true;
  String? error;
  Usuario? usuario;

  bool editando = false;
  bool guardando = false;
  bool subiendoFoto = false;

  Conductor? get conductor => _conductores.conductor;

  /// Elige una foto de la galería y la sube como foto de perfil del conductor.
  /// Devuelve true si se actualizó; null si el usuario canceló la selección.
  Future<bool?> cambiarFoto() async {
    final XFile? img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (img == null) return null;
    subiendoFoto = true;
    notifyListeners();
    final multipart = await MultipartFile.fromFile(img.path, filename: img.name);
    final res = await _conductores.subirFoto(multipart);
    subiendoFoto = false;
    final ok = res.isSuccess;
    if (!ok) error = res.when(ok: (_) => null, err: (f) => f.message);
    notifyListeners();
    return ok;
  }

  Future<void> cargar() async {
    cargando = true;
    notifyListeners();
    await _conductores.cargar();
    final res = await _usuarios.perfil(forzar: true);
    res.when(ok: (u) => usuario = u, err: (f) => error = f.message);
    cargando = false;
    notifyListeners();
  }

  void activarEdicion(bool v) {
    editando = v;
    notifyListeners();
  }

  Future<bool> guardar({
    required String nombre,
    String? email,
    String? telefono,
  }) async {
    guardando = true;
    notifyListeners();
    final res = await _usuarios.actualizar(
        nombre: nombre, email: email, telefono: telefono);
    guardando = false;
    final ok = res.isSuccess;
    if (ok) {
      usuario = res.valueOrNull;
      editando = false;
    } else {
      error = res.when(ok: (_) => null, err: (f) => f.message);
    }
    notifyListeners();
    return ok;
  }

  Future<void> cerrarSesion() async {
    await _auth.cerrarSesion();
    _conductores.limpiar();
    _usuarios.limpiar();
  }
}

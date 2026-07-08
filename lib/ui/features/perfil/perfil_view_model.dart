import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../domain/models/conductor.dart';
import '../../../domain/models/usuario.dart';
import '../../core/tab_activa.dart';

/// Estado del Perfil del conductor: datos personales, vehículo/documentos y
/// cierre de sesión. El nombre y el celular son la identidad verificada y no
/// se editan desde la app; solo el correo.
class PerfilViewModel extends ChangeNotifier {
  PerfilViewModel(this._usuarios, this._conductores, this._auth, this._tab) {
    _tab.addListener(_onTabActiva);
  }

  final UsuarioRepository _usuarios;
  final ConductorRepository _conductores;
  final AuthRepository _auth;
  final TabActiva _tab;

  /// Refresco silencioso al volver a este tab (estrellas/foto al día).
  void _onTabActiva() {
    if (_tab.indice == TabActiva.perfil) _cargar(silencioso: true);
  }

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

  Future<void> cargar() => _cargar();

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      cargando = true;
      notifyListeners();
    }
    await _conductores.cargar(forzar: silencioso);
    final res = await _usuarios.perfil(forzar: true);
    res.when(ok: (u) => usuario = u, err: (f) => error = f.message);
    cargando = false;
    notifyListeners();
  }

  void activarEdicion(bool v) {
    editando = v;
    notifyListeners();
  }

  /// Guarda los datos editables del perfil (solo el correo: nombre y celular
  /// son la identidad verificada del conductor).
  Future<bool> guardar({String? email}) async {
    guardando = true;
    notifyListeners();
    final res = await _usuarios.actualizar(email: email);
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
    // Deja al conductor FUERA de línea en el backend antes de borrar el JWT: si
    // no, seguiría `en_linea=1` y el dispatcher podría ofrecerle pedidos con la
    // app cerrada. Best-effort: no bloquea el logout si la red falla.
    if (_conductores.enLinea) {
      await _conductores.cambiarEnLinea(false);
    }
    await _auth.cerrarSesion();
    _conductores.limpiar();
    _usuarios.limpiar();
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabActiva);
    super.dispose();
  }
}

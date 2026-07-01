import 'package:flutter/foundation.dart';

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

  Conductor? get conductor => _conductores.conductor;

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

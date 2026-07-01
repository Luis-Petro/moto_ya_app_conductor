import 'package:flutter/foundation.dart';

import '../../domain/models/sesion.dart';
import '../services/api_result.dart';
import '../services/auth_service.dart';
import '../services/notificacion_service.dart';
import '../services/push_service.dart';
import '../services/session_storage.dart';
import '../services/social_auth_service.dart';

/// Fuente de verdad de la autenticación. Expone el estado de sesión de forma
/// reactiva (para los guards de ruta) y orquesta los canales de login.
class AuthRepository extends ChangeNotifier {
  AuthRepository(
    this._auth,
    this._social,
    this._session,
    this._notificaciones,
    this._push,
  );

  final AuthService _auth;
  final SocialAuthService _social;
  final SessionStorage _session;
  final NotificacionService _notificaciones;
  final PushService _push;

  Sesion? _sesion;
  Sesion? get sesion => _sesion;
  bool get estaAutenticado => _sesion != null;

  bool _inicializado = false;
  bool get inicializado => _inicializado;

  /// Carga la sesión persistida al arrancar.
  Future<void> cargarSesion() async {
    _sesion = await _session.leer();
    _inicializado = true;
    notifyListeners();
  }

  Future<Result<Sesion>> registrar({
    required String nombre,
    String? telefono,
    String? email,
    required String password,
  }) async {
    final res = await _auth.register(
        nombre: nombre, telefono: telefono, email: email, password: password);
    return _persistirSiOk(res);
  }

  Future<Result<Sesion>> loginEmail(String email, String password) async {
    return _persistirSiOk(await _auth.login(email: email, password: password));
  }

  Future<Result<void>> solicitarOtp(String telefono) {
    return _auth.solicitarOtp(telefono);
  }

  Future<Result<Sesion>> verificarOtp({
    required String telefono,
    required String codigo,
    String? nombre,
  }) async {
    return _persistirSiOk(
        await _auth.verificarOtp(telefono: telefono, codigo: codigo, nombre: nombre));
  }

  Future<Result<Sesion>> loginGoogle() async {
    final idToken = await _social.googleIdToken();
    if (idToken == null) {
      return const Err(Failure('Inicio con Google cancelado.'));
    }
    return _persistirSiOk(await _auth.google(idToken));
  }

  /// Cierra la sesión: da de baja el token push y limpia el almacenamiento.
  Future<void> cerrarSesion() async {
    final token = await _push.obtenerToken();
    if (token != null) {
      await _notificaciones.eliminarToken(token);
    }
    await _session.borrar();
    _sesion = null;
    notifyListeners();
  }

  /// Invocado por el ApiClient ante un 401 (sesión expirada).
  Future<void> sesionExpirada() async {
    await _session.borrar();
    _sesion = null;
    notifyListeners();
  }

  /// Registra el token push tras autenticarse (best-effort).
  Future<void> registrarTokenPush() async {
    final token = await _push.obtenerToken();
    if (token != null) {
      await _notificaciones.registrarToken(token, plataforma: _push.plataforma);
    }
  }

  Future<Result<Sesion>> _persistirSiOk(Result<Sesion> res) async {
    if (res case Ok<Sesion>(value: final s)) {
      await _session.guardar(s);
      _sesion = s;
      notifyListeners();
      await registrarTokenPush();
    }
    return res;
  }
}

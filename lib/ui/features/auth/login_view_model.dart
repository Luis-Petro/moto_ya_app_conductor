import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._auth);

  final AuthRepository _auth;

  bool _cargando = false;
  bool get cargando => _cargando;

  bool _googleCargando = false;
  bool get googleCargando => _googleCargando;

  String? _error;
  String? get error => _error;

  Future<bool> loginEmail(String email, String password) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    final res = await _auth.loginEmail(email.trim(), password);
    _cargando = false;
    final ok = res.isSuccess;
    if (!ok) _error = res.when(ok: (_) => null, err: (f) => f.message);
    notifyListeners();
    return ok;
  }

  Future<bool> loginGoogle() async {
    _googleCargando = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _auth.loginGoogle();
      final ok = res.isSuccess;
      if (!ok) _error = res.when(ok: (_) => null, err: (f) => f.message);
      return ok;
    } catch (_) {
      _error = 'No se pudo iniciar sesión con Google.';
      return false;
    } finally {
      _googleCargando = false;
      notifyListeners();
    }
  }

  bool _recuperandoPassword = false;
  bool get recuperandoPassword => _recuperandoPassword;

  /// Pide el enlace de recuperación. Devuelve el mensaje de error o null si
  /// salió. Ojo: un null **no** significa que la cuenta exista — el backend
  /// responde igual en ambos casos y el aviso al usuario debe ser neutro.
  Future<String?> recuperarPassword(String email) async {
    _recuperandoPassword = true;
    notifyListeners();
    final res = await _auth.solicitarRecuperacionPassword(email.trim());
    _recuperandoPassword = false;
    notifyListeners();
    return res.when(ok: (_) => null, err: (f) => f.message);
  }

  Future<bool> solicitarOtp(String telefonoE164) async {
    final res = await _auth.solicitarOtp(telefonoE164);
    if (!res.isSuccess) {
      _error = res.when(ok: (_) => null, err: (f) => f.message);
      notifyListeners();
    }
    return res.isSuccess;
  }
}

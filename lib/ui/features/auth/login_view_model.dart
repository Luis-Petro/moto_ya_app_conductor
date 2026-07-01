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

  Future<bool> solicitarOtp(String telefonoE164) async {
    final res = await _auth.solicitarOtp(telefonoE164);
    if (!res.isSuccess) {
      _error = res.when(ok: (_) => null, err: (f) => f.message);
      notifyListeners();
    }
    return res.isSuccess;
  }
}

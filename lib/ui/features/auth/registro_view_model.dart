import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';

/// Estado y lógica de la pantalla de registro (canal teléfono + OTP).
class RegistroViewModel extends ChangeNotifier {
  RegistroViewModel(this._auth);

  final AuthRepository _auth;

  bool _enviando = false;
  bool get enviando => _enviando;

  String? _error;
  String? get error => _error;

  /// Solicita el código OTP al teléfono. Devuelve true si se envió.
  Future<bool> solicitarCodigo(String telefonoE164) async {
    _enviando = true;
    _error = null;
    notifyListeners();

    final res = await _auth.solicitarOtp(telefonoE164);
    _enviando = false;
    final ok = res.isSuccess;
    if (!ok) {
      _error = res.when(ok: (_) => null, err: (f) => f.message);
    }
    notifyListeners();
    return ok;
  }
}

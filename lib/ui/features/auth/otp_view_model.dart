import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';

class OtpViewModel extends ChangeNotifier {
  OtpViewModel(this._auth, this.telefono, this.nombre);

  final AuthRepository _auth;
  final String telefono;
  final String? nombre;

  bool _verificando = false;
  bool get verificando => _verificando;

  bool _reenviando = false;
  bool get reenviando => _reenviando;

  String? _error;
  String? get error => _error;

  Future<bool> verificar(String codigo) async {
    _verificando = true;
    _error = null;
    notifyListeners();
    final res = await _auth.verificarOtp(
        telefono: telefono, codigo: codigo, nombre: nombre);
    _verificando = false;
    final ok = res.isSuccess;
    if (!ok) _error = res.when(ok: (_) => null, err: (f) => f.message);
    notifyListeners();
    return ok;
  }

  Future<bool> reenviar() async {
    _reenviando = true;
    notifyListeners();
    final res = await _auth.solicitarOtp(telefono);
    _reenviando = false;
    notifyListeners();
    return res.isSuccess;
  }
}

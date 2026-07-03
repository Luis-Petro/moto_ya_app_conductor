import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/usuario_repository.dart';

class OtpViewModel extends ChangeNotifier {
  OtpViewModel(this._auth, this._usuarios, this.telefono, this.nombre, this.email);

  final AuthRepository _auth;
  final UsuarioRepository _usuarios;
  final String telefono;
  final String? nombre;

  /// Correo capturado en el registro (el endpoint de OTP no lo acepta): se
  /// persiste vía PUT /usuarios/me tras verificar, ya con sesión.
  final String? email;

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
    if (ok) {
      // Persistir el correo del registro (best-effort: no bloquea el acceso).
      if (email != null && email!.trim().isNotEmpty) {
        await _usuarios.actualizar(email: email!.trim());
      }
    } else {
      _error = res.when(ok: (_) => null, err: (f) => f.message);
    }
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

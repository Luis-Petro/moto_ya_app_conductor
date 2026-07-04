import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';

/// Estado y lógica del registro: crea la cuenta (correo + contraseña + cédula +
/// teléfono) y dispara el OTP para validar el teléfono en el paso siguiente.
class RegistroViewModel extends ChangeNotifier {
  RegistroViewModel(this._auth);

  final AuthRepository _auth;

  bool _enviando = false;
  bool get enviando => _enviando;

  String? _error;
  String? get error => _error;

  /// Crea la cuenta y envía el código OTP al teléfono. Devuelve true si la
  /// cuenta quedó creada y el código salió (o al menos la cuenta se creó y se
  /// puede reenviar el código desde la pantalla de verificación).
  Future<bool> registrar({
    required String nombres,
    required String apellidos,
    required String cedula,
    required String telefonoE164,
    required String email,
    required String password,
  }) async {
    _enviando = true;
    _error = null;
    notifyListeners();

    final reg = await _auth.registrar(
      nombre: '$nombres $apellidos'.trim(),
      telefono: telefonoE164,
      email: email,
      cedula: cedula,
      password: password,
    );
    if (!reg.isSuccess) {
      _error = reg.when(ok: (_) => null, err: (f) => f.message);
      _enviando = false;
      notifyListeners();
      return false;
    }

    // Cuenta creada: pedir el código para validar el teléfono. Si el envío falla
    // igual se continúa al OTP (se puede reenviar allí; la cuenta ya existe).
    await _auth.solicitarOtp(telefonoE164);
    _enviando = false;
    notifyListeners();
    return true;
  }
}

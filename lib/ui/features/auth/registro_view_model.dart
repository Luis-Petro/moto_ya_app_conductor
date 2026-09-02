import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/auth_service.dart';

/// Cómo terminó el registro.
///
/// [yaExiste] no es un fallo: es **la misma persona**. Quien ya pide domicilios en
/// Zumbeo y ahora quiere repartir rellena este formulario con su mismo celular, y
/// recibía «El teléfono ya está registrado» — un callejón sin salida, porque quien lo
/// lee no tiene forma de saber que la cuenta que se lo impide es la suya. Sigue al
/// mismo sitio que un alta nueva: al código de ese número, que es el canal que **ya**
/// prueba que el celular es suyo.
enum ResultadoRegistro { creada, yaExiste, fallo }

/// Estado y lógica del registro: crea la cuenta (correo + contraseña + cédula +
/// teléfono) y dispara el OTP para validar el teléfono en el paso siguiente.
class RegistroViewModel extends ChangeNotifier {
  RegistroViewModel(this._auth);

  final AuthRepository _auth;

  bool _enviando = false;
  bool get enviando => _enviando;

  String? _error;
  String? get error => _error;

  /// Crea la cuenta y envía el código OTP al teléfono.
  ///
  /// Si el celular ya tiene cuenta, el backend lo marca con
  /// [AuthService.codigoCuentaYaExiste] y aquí se sigue igualmente al código: es la
  /// misma persona, y ese es el canal que prueba que el número es suyo. El correo o
  /// la cédula de una cuenta **distinta** siguen siendo un fallo — son dos personas,
  /// o un dedazo, y adivinar cuál no es tarea de esta pantalla.
  Future<ResultadoRegistro> registrar({
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
    final yaExiste = reg.when(
      ok: (_) => false,
      err: (f) => f.codigo == AuthService.codigoCuentaYaExiste,
    );
    if (!reg.isSuccess && !yaExiste) {
      _error = reg.when(ok: (_) => null, err: (f) => f.message);
      _enviando = false;
      notifyListeners();
      return ResultadoRegistro.fallo;
    }

    // Pedir el código para validar el teléfono. Si el envío falla igual se
    // continúa al OTP (se puede reenviar allí; la cuenta ya existe).
    await _auth.solicitarOtp(telefonoE164);
    _enviando = false;
    notifyListeners();
    return yaExiste ? ResultadoRegistro.yaExiste : ResultadoRegistro.creada;
  }
}

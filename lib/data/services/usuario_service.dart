import '../../domain/models/usuario.dart';
import '../models/api_mappers.dart';
import 'api_client.dart';
import 'api_result.dart';

/// Cliente de `/usuarios/me`.
class UsuarioService {
  UsuarioService(this._api);

  final ApiClient _api;

  Future<Result<Usuario>> obtenerPerfil() {
    return _api.get<Usuario>('/usuarios/me', parse: ApiMappers.usuario);
  }

  /// Ni el correo ni el celular se cambian aquí: ambos son credenciales de
  /// acceso y pasan por su flujo verificado ([solicitarCambioEmail] /
  /// [solicitarCambioTelefono]). El backend ignora esos campos en este PUT.
  Future<Result<Usuario>> actualizarPerfil({
    String? nombre,
    int? municipioId,
  }) {
    return _api.put<Usuario>(
      '/usuarios/me',
      body: {
        'nombre': nombre,
        'municipioId': municipioId,
      },
      parse: ApiMappers.usuario,
    );
  }

  /// Paso 1 del cambio de correo: envía un código al correo NUEVO.
  Future<Result<void>> solicitarCambioEmail(String email) {
    return _api.post<void>('/usuarios/me/email/solicitar', body: {'email': email});
  }

  /// Paso 2: confirma el código y aplica el correo nuevo.
  Future<Result<Usuario>> verificarCambioEmail(String codigo) {
    return _api.post<Usuario>('/usuarios/me/email/verificar',
        body: {'codigo': codigo}, parse: ApiMappers.usuario);
  }

  /// Paso 1 del cambio de celular: envía un OTP al número NUEVO.
  Future<Result<void>> solicitarCambioTelefono(String telefono) {
    return _api.post<void>('/usuarios/me/telefono/solicitar',
        body: {'telefono': telefono});
  }

  /// Paso 2: confirma el código, aplica el número y lo marca verificado.
  /// Verificación del celular que la cuenta **ya tiene**, sin cambiarlo.
  ///
  /// Flujo aparte del cambio: pedir "cambiar" al mismo número choca contra la
  /// validación de unicidad del backend y responde 409.
  Future<Result<void>> solicitarVerificacionTelefonoActual() {
    return _api.post<void>('/usuarios/me/telefono/verificar-actual/solicitar');
  }

  Future<Result<Usuario>> verificarTelefonoActual(String codigo) {
    return _api.post<Usuario>('/usuarios/me/telefono/verificar-actual',
        body: {'codigo': codigo}, parse: ApiMappers.usuario);
  }

  /// Verificación del correo que la cuenta ya tiene, sin cambiarlo.
  Future<Result<void>> solicitarVerificacionEmailActual() {
    return _api.post<void>('/usuarios/me/email/verificar-actual/solicitar');
  }

  Future<Result<Usuario>> verificarEmailActual(String codigo) {
    return _api.post<Usuario>('/usuarios/me/email/verificar-actual',
        body: {'codigo': codigo}, parse: ApiMappers.usuario);
  }

  Future<Result<Usuario>> verificarCambioTelefono(String codigo) {
    return _api.post<Usuario>('/usuarios/me/telefono/verificar',
        body: {'codigo': codigo}, parse: ApiMappers.usuario);
  }

  /// Baja de la propia cuenta.
  ///
  /// El backend anonimiza los datos personales, borra los documentos y cierra el
  /// acceso; conserva el histórico de pedidos y comisiones porque involucra a la
  /// otra parte. Responde **409** con el motivo si hay un pedido en curso o deuda
  /// pendiente, y ese mensaje se le muestra al conductor tal cual.
  Future<Result<void>> eliminarCuenta() {
    return _api.delete<void>('/usuarios/me');
  }
}

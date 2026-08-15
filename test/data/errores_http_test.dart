import 'dart:typed_data';

import 'package:app_conductor/data/services/api_client.dart';
import 'package:app_conductor/data/services/api_result.dart';
import 'package:app_conductor/data/services/session_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que respondió el servidor y lo que ve el usuario tienen que coincidir.
///
/// "Error de red." era la respuesta de la app a media docena de situaciones
/// distintas, y manda a revisar el wifi a quien lo único que hizo fue llegar
/// tarde a una oferta. Además, un fallo que pierde su `statusCode` deja a la
/// pantalla sin con qué decidir: es lo que necesita la tarjeta del pedido
/// entrante para distinguir "esta oferta ya no está" de "no hay internet".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  /// Un ApiClient con las MISMAS opciones que en producción (incluido
  /// `validateStatus`, que es lo que decide si un 4xx lanza o no) y un
  /// adaptador que responde lo que diga el test.
  ApiClient clienteQue(
    Future<ResponseBody> Function(RequestOptions o) responder, {
    void Function()? alExpirar,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://local/Api',
        validateStatus: (s) => s != null && s < 500,
      ),
    )..httpClientAdapter = _Adaptador(responder);
    return ApiClient(SessionStorage(), dio: dio)..onUnauthorized = alExpirar;
  }

  ResponseBody json(String cuerpo, int codigo) => ResponseBody.fromString(
    cuerpo,
    codigo,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  Failure fallo(Result<dynamic> r) =>
      r.when(ok: (_) => throw StateError('se esperaba un fallo'), err: (f) => f);

  test('un 403 conserva su código para que la pantalla decida', () async {
    final api = clienteQue(
      (_) async => json('{"message":"No participas en este pedido"}', 403),
    );

    final f = fallo(await api.get<dynamic>('/pedidos/1'));

    expect(f.statusCode, 403);
    expect(f.kind, isNot(FailureKind.network));
  });

  test('un 502 sin mensaje no se llama "Error de red."', () async {
    final api = clienteQue((_) async => json('', 502));

    final f = fallo(await api.get<dynamic>('/pedidos/1'));

    expect(f.statusCode, 502);
    expect(f.kind, isNot(FailureKind.network));
    expect(f.message, isNot('Error de red.'));
  });

  test('sin respuesta del servidor el mensaje habla de conexión', () async {
    // `unknown` es el cajón de sastre de Dio: DNS, TLS, la red que se cae a
    // mitad. No hay respuesta, así que sí es un fallo de red — pero contado.
    final api = clienteQue(
      (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.unknown,
      ),
    );

    final f = fallo(await api.get<dynamic>('/pedidos/1'));

    expect(f.kind, FailureKind.network);
    expect(f.message, isNot('Error de red.'));
    expect(f.message.toLowerCase(), contains('conexión'));
  });

  test('un corte de conexión sigue siendo un fallo de red', () async {
    final api = clienteQue(
      (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      ),
    );

    expect(fallo(await api.get<dynamic>('/pedidos/1')).kind,
        FailureKind.network);
  });

  test('un 401 fuera de /auth sigue cerrando la sesión', () async {
    var expirada = false;
    final api = clienteQue(
      (_) async => json('{"message":"Token vencido"}', 401),
      alExpirar: () => expirada = true,
    );

    await api.get<dynamic>('/pedidos/1');

    expect(expirada, isTrue);
  });

  test('un 401 de /auth no cierra la sesión', () async {
    // Equivocarse en el OTP no es una sesión que expira: si esto disparara el
    // logout, el registro se quedaría a medias con una pantalla en blanco.
    var expirada = false;
    final api = clienteQue(
      (_) async => json('{"message":"Código inválido"}', 401),
      alExpirar: () => expirada = true,
    );

    await api.post<dynamic>('/auth/otp/verificar');

    expect(expirada, isFalse);
  });
}

/// Adaptador que responde lo que le diga el test, sin salir a la red.
class _Adaptador implements HttpClientAdapter {
  _Adaptador(this.responder);

  final Future<ResponseBody> Function(RequestOptions o) responder;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => responder(options);
}

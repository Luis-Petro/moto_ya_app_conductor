import 'dart:convert';

import 'package:app_conductor/data/services/api_client.dart';
import 'package:app_conductor/data/services/dispositivo_service.dart';
import 'package:app_conductor/data/services/session_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptador que responde 200 y se queda con lo que se le pidiÃ³ enviar.
class _Espia implements HttpClientAdapter {
  RequestOptions? ultima;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? _,
      Future<void>? __) async {
    ultima = options;
    return ResponseBody.fromString(jsonEncode({'ok': true}), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

/// El equipo viaja en cabeceras y no en el cuerpo: asÃ­ ninguna llamada de la app
/// tiene que acordarse de mandarlo, y el servidor puede tratarlas como
/// opcionales sin romper a nadie.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('toda peticiÃ³n lleva el identificador del dispositivo', () async {
    final espia = _Espia();
    final dio = Dio()..httpClientAdapter = espia;
    final cliente = ApiClient(SessionStorage(),
        dio: dio, dispositivo: DispositivoService());

    await cliente.get<dynamic>('https://api.example/Api/usuarios/me');

    final enviado = espia.ultima!.headers['X-Dispositivo-Id'];
    expect(enviado, isNotNull);
    expect(enviado, isNotEmpty);
    expect(espia.ultima!.headers.containsKey('X-Dispositivo'), isTrue);
  });

  test('sin servicio de dispositivo la peticiÃ³n sale igual', () async {
    // El cliente sigue funcionando sin las cabeceras: son contexto de soporte,
    // no autenticaciÃ³n, y un fallo suyo no puede tumbar una llamada.
    final espia = _Espia();
    final dio = Dio()..httpClientAdapter = espia;
    final cliente = ApiClient(SessionStorage(), dio: dio);

    final res = await cliente.get<dynamic>('https://api.example/Api/usuarios/me');

    expect(res.isSuccess, isTrue);
    expect(espia.ultima!.headers.containsKey('X-Dispositivo-Id'), isFalse);
  });
}

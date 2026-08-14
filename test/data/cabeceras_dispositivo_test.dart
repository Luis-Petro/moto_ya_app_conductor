import 'dart:io';

import 'package:app_conductor/data/services/api_client.dart';
import 'package:app_conductor/data/services/dispositivo_service.dart';
import 'package:app_conductor/data/services/session_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// El equipo viaja en cabeceras y no en el cuerpo: asÃ­ ninguna llamada de la app
/// tiene que acordarse de mandarlo, y el servidor puede tratarlas como
/// opcionales sin romper a nadie.
///
/// **Estos tests salen por la red de verdad** (a un servidor en localhost) en vez
/// de contra un adaptador falso, y esa es la parte importante. Un adaptador falso
/// no ejecuta la validaciÃ³n de cabeceras de `dart:io`, que rechaza cualquier byte
/// fuera de ASCII lanzando `FormatException` **dentro** del adaptador de Dio. Con
/// un separador `Â·` en la descripciÃ³n, todas las peticiones de las dos apps
/// morÃ­an con "error de red" sin salir del telÃ©fono â€” y el test con adaptador
/// falso pasaba en verde.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer servidor;
  late List<HttpHeaders> recibidas;
  HttpOverrides? overridesPrevias;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    // `TestWidgetsFlutterBinding` sustituye el HttpClient por uno que devuelve
    // 400 sin salir a la red. AquÃ­ hace falta el de verdad: lo que se estÃ¡
    // probando es justamente la validaciÃ³n de cabeceras de `dart:io`, y con un
    // cliente falso â€”o con un adaptador falso de Dioâ€” este test pasa en verde
    // con el bug dentro.
    overridesPrevias = HttpOverrides.current;
    HttpOverrides.global = _RedReal();
    recibidas = [];
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servidor.listen((req) async {
      recibidas.add(req.headers);
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write('{"ok":true}');
      await req.response.close();
    });
  });

  tearDown(() async {
    HttpOverrides.global = overridesPrevias;
    await servidor.close(force: true);
  });

  String url() => 'http://127.0.0.1:${servidor.port}/Api/usuarios/me';

  ApiClient cliente({DispositivoService? dispositivo}) =>
      ApiClient(SessionStorage(), dio: Dio(), dispositivo: dispositivo);

  test('la peticiÃ³n llega con el identificador del dispositivo', () async {
    final res = await cliente(dispositivo: DispositivoService())
        .get<dynamic>(url());

    expect(res.isSuccess, isTrue, reason: 'la peticiÃ³n tiene que salir');
    expect(recibidas.single.value('X-Dispositivo-Id'), isNotNull);
    expect(recibidas.single.value('X-Dispositivo'), isNotNull);
  });

  test('una descripciÃ³n con caracteres no ASCII no tumba la peticiÃ³n', () async {
    // El modelo lo reporta el fabricante: puede traer acentos o cualquier otro
    // alfabeto. Si eso llega crudo a la cabecera, dart:io lanza y la app queda
    // sin poder hablar con el backend.
    final res = await cliente(dispositivo: _EquipoRaro()).get<dynamic>(url());

    expect(res.isSuccess, isTrue);
    final descripcion = recibidas.single.value('X-Dispositivo')!;
    expect(descripcion.codeUnits.every((c) => c >= 32 && c <= 126), isTrue,
        reason: 'la cabecera tiene que ser ASCII imprimible: $descripcion');
  });

  test('sin servicio de dispositivo la peticiÃ³n sale igual', () async {
    // Son contexto de soporte, no autenticaciÃ³n: su ausencia no puede tumbar
    // una llamada.
    final res = await cliente().get<dynamic>(url());

    expect(res.isSuccess, isTrue);
    expect(recibidas.single.value('X-Dispositivo-Id'), isNull);
  });

  group('soloAscii', () {
    test('sustituye lo que no es ASCII imprimible por espacio', () {
      expect(DispositivoService.soloAscii('Xiaomi Â· Android'),
          'Xiaomi Android');
      expect(DispositivoService.soloAscii('MotÃ¶rhead\tX2'), 'Mot rhead X2');
    });

    test('el separador de las partes es ASCII', () {
      expect(DispositivoService.separador.codeUnits.every((c) => c < 128),
          isTrue);
    });
  });
}

/// Sin overrides: `HttpOverrides` sin redefinir nada devuelve el cliente real.
class _RedReal extends HttpOverrides {}

/// Un telÃ©fono cuyo modelo trae caracteres fuera de ASCII.
class _EquipoRaro implements DispositivoService {
  @override
  Future<String> id() async => 'abc-123';

  @override
  Future<String> descripcion() async => 'Xiaomi Ã‘andÃº Â· Android 13 Â· app 1.0.0';

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

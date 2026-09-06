import 'dart:async';

import 'package:app_conductor/data/services/api_client.dart';
import 'package:app_conductor/data/services/api_result.dart';
import 'package:app_conductor/data/services/lugar_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// La caché del catálogo de lugares, que la piden todas las pantallas con mapa.
///
/// Aquí viven dos reglas que costaron un diagnóstico largo en la app cliente y
/// que esta app arrastraba intactas: **un vacío no puede pesar lo mismo que un
/// catálogo bueno** y **un intento que no vuelve tiene que soltar el turno**.
/// Las dos producían el mismo píxel —un mapa sin marcadores— sin dejar rastro de
/// cuál había sido.
///
/// Su gemelo vive en `app_cliente/test/data/catalogo_de_lugares_test.dart`: los
/// dos servicios se mueven juntos.
///
/// Sin `testWidgets` en este fichero **a propósito**: con el binding de widgets
/// instalado, los `Timer` de un `test` normal caen en el reloj falso y no
/// avanzan nunca.
void main() {
  const municipio = 1;

  Map<String, dynamic> fila(int id, String nombre) => {
        'id': id,
        'nombre': nombre,
        'categoria': 'FARMACIA',
        'lat': 9.35,
        'lng': -75.95,
      };

  test('la primera consulta de la sesión completa', () async {
    // **El bug que dejaba mudo el mapa del Inicio.** `whenComplete` espera a lo
    // que le devuelvas, y `Map.remove` devuelve el valor que quitó — que era
    // este mismo futuro. Con `whenComplete(() => _enVuelo.remove(id))` escrito
    // con flecha, el futuro se quedaba esperándose a sí mismo: la petición
    // terminaba, la caché se llenaba, y `catalogoDeMapa` **no completaba
    // nunca**. Quien preguntara primero en la sesión —el mapa del Inicio, que se
    // monta antes que ninguna otra pantalla con mapa— se quedaba esperando para
    // siempre, sin marcadores, sin fallo que contar y sin nada que reintentar; y
    // todos los demás recibían el catálogo al instante desde la caché.
    //
    // Sin el plazo del test esto no falla: se cuelga.
    final api = _ApiFake([fila(1, 'Droguería La Fe')]);
    final servicio = LugarService(api);

    await expectLater(
      servicio.catalogoDeMapa(municipio),
      completion(hasLength(1)),
    );
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('un catálogo con sitios se cachea', () async {
    final api = _ApiFake([fila(1, 'Droguería La Fe')]);
    final servicio = LugarService(api);

    await servicio.catalogoDeMapa(municipio);
    await servicio.catalogoDeMapa(municipio);

    expect(api.llamadas, 1);
  });

  test('un vacío se recuerda mucho menos que un catálogo con sitios', () {
    // Un vacío es una afirmación mucho más frágil que una lista de cuarenta
    // sitios: deja de ser cierta en cuanto el administrador activa el primer
    // lugar. Guardarlo con la vigencia del catálogo bueno convertía una
    // respuesta vacía desafortunada en diez minutos de mapa mudo.
    expect(frescuraCatalogoVacio, lessThan(frescuraCatalogo));
  });

  test('un vacío sí se recuerda un rato', () async {
    // Lo contrario del test siguiente: al abrir la app varias pantallas
    // preguntan casi a la vez, y en un municipio sin sitios eso serían varias
    // peticiones idénticas.
    final api = _ApiFake(const []);
    final servicio = LugarService(api);

    await servicio.catalogoDeMapa(municipio);
    await servicio.catalogoDeMapa(municipio);

    expect(api.llamadas, 1);
  });

  test('pasada su vigencia, el vacío no bloquea la consulta siguiente',
      () async {
    final api = _ApiFake(const []);
    final servicio = LugarService(api, frescuraDelVacio: Duration.zero);

    expect(await servicio.catalogoDeMapa(municipio), isEmpty);
    api.datos = [fila(1, 'Droguería La Fe')];

    expect(await servicio.catalogoDeMapa(municipio), hasLength(1));
    expect(api.llamadas, 2, reason: 'el vacío se quedó de por vida');
  });

  test('un fallo no se cachea', () async {
    final api = _ApiFake([fila(1, 'Droguería La Fe')])..falla = true;
    final servicio = LugarService(api);

    expect(await servicio.catalogoDeMapa(municipio), isNull);
    api.falla = false;

    expect(await servicio.catalogoDeMapa(municipio), hasLength(1));
  });

  test('una petición que no vuelve vence y suelta el turno', () async {
    // Hasta ahora la entrada de peticiones en vuelo solo se borraba al
    // terminar: una que se quedara colgada la dejaba puesta para siempre y
    // **todos** los que preguntaran después en esa sesión se enganchaban al
    // mismo futuro muerto. La app entera sin catálogo y sin un solo error.
    final api = _ApiFake([fila(1, 'Droguería La Fe')])..cuelga = true;
    final servicio =
        LugarService(api, plazoDeGuarda: const Duration(milliseconds: 200));

    expect(await servicio.catalogoDeMapa(municipio), isNull);
    api.cuelga = false;

    expect(await servicio.catalogoDeMapa(municipio), hasLength(1),
        reason: 'el intento colgado se llevó por delante a los siguientes');
  });

  test('el plazo de guarda va por encima del timeout del cliente HTTP', () {
    // Si fuera más corto cortaría peticiones legítimas de una red lenta, que es
    // exactamente el parque de esta app. Solo tiene que cubrir lo que no vuelve
    // nunca.
    expect(plazoDeGuardaDelCatalogo, greaterThan(const Duration(seconds: 20)));
  });

  test('dos pantallas a la vez comparten una sola petición', () async {
    // Al abrir la app el mapa del Inicio y el del pedido activo arrancan casi al
    // mismo tiempo.
    final api = _ApiFake([fila(1, 'Droguería La Fe')],
        demora: const Duration(milliseconds: 20));
    final servicio = LugarService(api);

    await Future.wait([
      servicio.catalogoDeMapa(municipio),
      servicio.catalogoDeMapa(municipio),
    ]);

    expect(api.llamadas, 1);
  });
}

/// `ApiClient` de mentira: cuenta las peticiones y puede fallar o no responder.
class _ApiFake extends Fake implements ApiClient {
  _ApiFake(this.datos, {this.demora});

  List<Map<String, dynamic>> datos;
  final Duration? demora;

  /// Devuelve un error, como una red que se cae.
  bool falla = false;

  /// No responde nunca: lo que el plazo de guarda existe para acotar.
  bool cuelga = false;

  int llamadas = 0;

  @override
  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic data)? parse,
  }) async {
    llamadas++;
    if (cuelga) return Completer<Result<T>>().future;
    if (demora != null) await Future<void>.delayed(demora!);
    if (falla) {
      return const Err(Failure('sin conexión', kind: FailureKind.network));
    }
    return Ok<T>(parse!(datos));
  }
}

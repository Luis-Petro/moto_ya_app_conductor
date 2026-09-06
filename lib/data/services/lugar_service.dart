import 'package:flutter/foundation.dart';

import '../../domain/models/lugar.dart';
import '../models/api_mappers.dart';
import 'api_client.dart';
import 'api_result.dart';

/// Cliente de `/lugares`: catálogo de puntos de interés del municipio.
///
/// El conductor no solo consulta: **aporta**. Cada entrega es un punto que él
/// ya verificó en la calle, y ese es el motor real del catálogo en municipios
/// donde OpenStreetMap está prácticamente vacío de comercio.
class LugarService {
  LugarService(this._api, {Duration? frescuraDelVacio, Duration? plazoDeGuarda})
      : frescuraDelVacio = frescuraDelVacio ?? frescuraCatalogoVacio,
        plazoDeGuarda = plazoDeGuarda ?? plazoDeGuardaDelCatalogo;

  final ApiClient _api;

  /// Cuánto se recuerda un catálogo vacío. Se puede acortar al construir el
  /// servicio: comprobar que el vacío se olvida no puede costar un minuto de
  /// reloj real.
  final Duration frescuraDelVacio;

  /// Cuánto se espera a un intento antes de darlo por perdido y soltarlo.
  final Duration plazoDeGuarda;

  Future<Result<List<Lugar>>> buscar({
    required int municipioId,
    String? q,
    int? limit,
  }) {
    return _api.get<List<Lugar>>(
      '/lugares',
      query: {
        'municipioId': municipioId,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (limit != null) 'limit': limit,
      },
      parse: (data) =>
          (data as List).map(ApiMappers.lugar).toList(growable: false),
    );
  }

  /// Todos los lugares activos del municipio, para pintarlos en el mapa.
  /// Sin tope: paginar dejaría marcadores invisibles sin avisar.
  Future<Result<List<Lugar>>> paraMapa({required int municipioId}) {
    return _api.get<List<Lugar>>(
      '/lugares/mapa',
      query: {'municipioId': municipioId},
      parse: (data) =>
          (data as List).map(ApiMappers.lugar).toList(growable: false),
    );
  }

  /// Catálogo del municipio para dibujarlo, **cacheado en memoria**.
  ///
  /// El conductor tiene el mapa abierto todo el pedido y pasa por él varias
  /// veces al día (inicio → pedido activo → detalle). Es un catálogo curado a
  /// mano: entre esas aperturas no cambia, y él trabaja con datos propios.
  ///
  /// Nunca falla hacia la UI: sin catálogo el mapa sigue sirviendo, solo va sin
  /// marcadores. Un error tampoco se cachea, para que la pantalla siguiente
  /// reintente.
  ///
  /// **Devuelve `null` cuando falló**, y una lista vacía cuando el municipio no
  /// tiene lugares. Antes las dos cosas eran la misma lista vacía, y por eso un
  /// fallo de red, un 400 por municipio inválido y un catálogo genuinamente sin
  /// nada se veían exactamente igual: un mapa sin marcadores y ni una pista de
  /// por qué. Quien llama decide si reintenta.
  ///
  /// **Un intento que no vuelve caduca.** Hasta ahora la entrada de [_enVuelo]
  /// solo se borraba cuando la petición terminaba: una que se quedara colgada
  /// —un interceptor que no llama a `handler.next`, un socket que no cierra— la
  /// dejaba puesta para siempre y **todos** los que preguntaran después en esa
  /// sesión se enganchaban al mismo futuro muerto. La app entera sin catálogo y
  /// sin un solo error. El plazo de guarda va holgadamente por encima del
  /// `receiveTimeout` del `ApiClient`, así que en una red lenta normal ya habrá
  /// fallado antes por su cuenta; esto solo cubre lo que no vuelve nunca.
  Future<List<Lugar>?> catalogoDeMapa(int municipioId) {
    final cacheado = _cache[municipioId];
    if (cacheado != null && _estaFresco(cacheado)) {
      return Future.value(cacheado.lugares);
    }
    // Una sola petición aunque dos pantallas la pidan a la vez: al abrir la app
    // el mapa de zonas y el del pedido activo arrancan casi al mismo tiempo.
    final enVuelo = _enVuelo[municipioId];
    if (enVuelo != null) return enVuelo;
    final futuro = _traerCatalogo(municipioId)
        .timeout(plazoDeGuarda, onTimeout: () {
          _trazar(municipioId, 'venció',
              detalle: 'sin respuesta en $plazoDeGuarda');
          return _cache[municipioId]?.lugares;
        })
        // Se suelta también al vencer, que es el punto entero: el siguiente que
        // pregunte tiene que lanzar un intento de verdad, no heredar este.
        //
        // **Cuerpo de bloque, no flecha, y esto no es estilo.** `whenComplete`
        // espera a lo que le devuelvas, y `Map.remove` devuelve **el valor que
        // quitó** — que aquí es este mismo futuro. Con `=> _enVuelo.remove(...)`
        // el futuro se quedaba esperándose a sí mismo: `_traerCatalogo`
        // terminaba, la caché se llenaba, y `catalogoDeMapa` **no completaba
        // nunca**. Quien preguntara primero en la sesión se quedaba esperando
        // para siempre —sin marcadores, sin fallo que contar y sin nada que
        // reintentar— y todos los demás recibían el catálogo al instante desde
        // la caché. En esta app el que pregunta primero es **siempre** el mapa
        // del Inicio, que se monta antes que ninguna otra pantalla con mapa.
        .whenComplete(() {
      _enVuelo.remove(municipioId);
    });
    _enVuelo[municipioId] = futuro;
    return futuro;
  }

  Future<List<Lugar>?> _traerCatalogo(int municipioId) async {
    final res = await paraMapa(municipioId: municipioId);
    return res.when(
      ok: (lugares) {
        _cache[municipioId] = _CatalogoCacheado(lugares);
        if (lugares.isEmpty) {
          _trazar(municipioId, 'vacío',
              detalle: 'el municipio no tiene lugares activos; se cargan desde '
                  'el panel. Se recuerda $frescuraDelVacio');
        } else {
          _trazar(municipioId, 'llegó', lugares: lugares.length);
        }
        return lugares;
      },
      err: (f) {
        _trazar(municipioId, 'falló',
            detalle: '${f.statusCode} ${f.message}. No se cachea el fallo');
        return _cache[municipioId]?.lugares;
      },
    );
  }

  /// Un catálogo **con lugares** se recuerda diez minutos; uno **vacío**, mucho
  /// menos. Ver el motivo en [frescuraCatalogoVacio].
  bool _estaFresco(_CatalogoCacheado c) =>
      DateTime.now().difference(c.traidoEn) <
      (c.lugares.isEmpty ? frescuraDelVacio : frescuraCatalogo);

  /// Una línea por intento, con prefijo estable para poder filtrarla.
  ///
  /// Sale también en un **APK de release** —lo que desaparece al compilar son
  /// los `assert` y lo guardado tras `kDebugMode`, no esto—, que es justo donde
  /// hace falta: "a veces no cargan los sitios" se reporta desde un teléfono con
  /// la app instalada, y hasta ahora los cuatro desenlaces de aquí producían el
  /// mismo píxel (un mapa sin marcadores) sin dejar forma de saber cuál fue.
  ///
  /// No lleva ningún dato personal: id de municipio, desenlace y un conteo.
  void _trazar(int municipioId, String desenlace,
      {int? lugares, String? detalle}) {
    final cuenta = lugares == null ? '' : ' · $lugares lugares';
    final extra = detalle == null ? '' : ' · $detalle';
    debugPrint(
        'LugarService: municipio $municipioId · $desenlace$cuenta$extra');
  }

  final Map<int, _CatalogoCacheado> _cache = {};
  final Map<int, Future<List<Lugar>?>> _enVuelo = {};

  /// Propone un lugar nuevo. Queda pendiente de revisión del administrador
  /// antes de aparecerle a los clientes.
  Future<Result<Lugar>> proponer({
    required String nombre,
    required CategoriaLugar categoria,
    required double lat,
    required double lng,
    String? referencia,
    int? municipioId,
  }) {
    return _api.post<Lugar>(
      '/lugares/propuestos',
      body: {
        'nombre': nombre,
        'categoria': categoria.name.toUpperCase(),
        'lat': lat,
        'lng': lng,
        if (referencia != null && referencia.trim().isNotEmpty)
          'referencia': referencia.trim(),
        if (municipioId != null) 'municipioId': municipioId,
      },
      parse: ApiMappers.lugar,
    );
  }
}

/// Cuánto se considera fresco un catálogo **con lugares**. Diez minutos es más
/// de lo que dura un pedido, y menos de lo que tarda un administrador en aprobar
/// un lugar y querer verlo.
const Duration frescuraCatalogo = Duration(minutes: 10);

/// Cuánto se recuerda un catálogo **vacío**, que es mucho menos.
///
/// Un vacío es una afirmación bastante más frágil que una lista de cuarenta
/// sitios: deja de ser cierta en cuanto el administrador activa el primer lugar,
/// y guardarla con la vigencia del catálogo bueno convierte una respuesta vacía
/// desafortunada en diez minutos de mapa mudo en todas las pantallas a la vez.
/// Un minuto cubre el arranque —que es cuando varias preguntan casi a la vez— y
/// deja que el siguiente regreso al Inicio vuelva a preguntar de verdad.
const Duration frescuraCatalogoVacio = Duration(seconds: 60);

/// Plazo de guarda del futuro compartido de [LugarService.catalogoDeMapa]. Ver
/// el motivo allí.
const Duration plazoDeGuardaDelCatalogo = Duration(seconds: 30);

class _CatalogoCacheado {
  _CatalogoCacheado(this.lugares) : traidoEn = DateTime.now();

  final List<Lugar> lugares;
  final DateTime traidoEn;
}

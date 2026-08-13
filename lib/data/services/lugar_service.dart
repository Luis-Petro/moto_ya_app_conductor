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
  LugarService(this._api);

  final ApiClient _api;

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
  Future<List<Lugar>> catalogoDeMapa(int municipioId) {
    final cacheado = _cache[municipioId];
    if (cacheado != null && cacheado.fresco) {
      return Future.value(cacheado.lugares);
    }
    // Una sola petición aunque dos pantallas la pidan a la vez: al abrir la app
    // el mapa de zonas y el del pedido activo arrancan casi al mismo tiempo.
    return _enVuelo[municipioId] ??= _traerCatalogo(municipioId)
        .whenComplete(() => _enVuelo.remove(municipioId));
  }

  Future<List<Lugar>> _traerCatalogo(int municipioId) async {
    final res = await paraMapa(municipioId: municipioId);
    return res.when(
      ok: (lugares) {
        _cache[municipioId] = _CatalogoCacheado(lugares);
        return lugares;
      },
      err: (_) => _cache[municipioId]?.lugares ?? const <Lugar>[],
    );
  }

  final Map<int, _CatalogoCacheado> _cache = {};
  final Map<int, Future<List<Lugar>>> _enVuelo = {};

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

/// Cuánto se considera fresco el catálogo en memoria. Diez minutos es más de lo
/// que dura un pedido, y menos de lo que tarda un administrador en aprobar un
/// lugar y querer verlo.
const Duration _frescuraCatalogo = Duration(minutes: 10);

class _CatalogoCacheado {
  _CatalogoCacheado(this.lugares) : traidoEn = DateTime.now();

  final List<Lugar> lugares;
  final DateTime traidoEn;

  bool get fresco => DateTime.now().difference(traidoEn) < _frescuraCatalogo;
}

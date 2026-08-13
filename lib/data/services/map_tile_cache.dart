import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:path_provider/path_provider.dart';

/// Caché en disco de los tiles del mapa, bajo demanda.
///
/// Se inicializa una vez al arrancar la app ([init]) y expone el [store] que
/// consume `osmTileLayer()` a través de un `CachedTileProvider`. Cada tile que
/// el conductor ve se guarda en disco: al volver a esa zona (paneos, el pedido
/// siguiente, re-abrir la app) carga desde disco, instantáneo y sin datos.
///
/// En la app conductor esto pesa más que en la del cliente por tres razones: el
/// mapa está abierto durante todo el domicilio, el conductor se mueve por el
/// mismo municipio todos los días —así que los tiles se repiten casi siempre—, y
/// los datos los paga él. Encima, el proveedor de tiles tiene cuota diaria: cada
/// tile que sale de disco es un crédito que no se gasta.
///
/// Solo persiste lo que realmente se visualiza — no hace descarga masiva.
///
/// Si la inicialización falla (p. ej. plataforma sin directorio de caché),
/// [store] queda en `null` y el mapa cae al `NetworkTileProvider` sin
/// persistencia: degradación silenciosa, el mapa sigue funcionando.
class MapTileCache {
  MapTileCache._();

  static CacheStore? _store;

  /// Store de disco compartido por todas las capas de tiles; `null` si no se
  /// pudo inicializar.
  static CacheStore? get store => _store;

  /// Inicializa la caché de tiles. Llamar una vez en `main()` antes de `runApp`.
  static Future<void> init() async {
    try {
      final dir = await getApplicationCacheDirectory();
      _store = FileCacheStore('${dir.path}/map_tiles');
    } catch (_) {
      _store = null; // el mapa seguirá funcionando sin caché en disco
    }
  }
}

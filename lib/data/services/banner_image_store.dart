import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:path_provider/path_provider.dart';

/// Descarga de las imágenes de los banners, **con caché en disco**.
///
/// `Image.network` no cachea en disco: cada apertura del Inicio volvería a bajar
/// los mismos cientos de kilobytes. El conductor abre el Inicio decenas de veces
/// al día, así que aquí no es una comodidad: es su factura de datos.
///
/// Se reutiliza el `dio_cache_interceptor` que las dos apps ya traen para los
/// tiles del mapa, en vez de añadir un paquete de imágenes en red: hace lo mismo
/// y es una dependencia menos que mantener antes de cada release.
///
/// La URL lleva la key del objeto en R2, así que **reemplazar la imagen de un
/// banner cambia su URL** y la caché no puede servir una versión vieja.
class BannerImageStore {
  BannerImageStore({Dio? dio}) : _dio = dio ?? Dio() {
    final store = _store;
    if (store != null) {
      _dio.interceptors.add(DioCacheInterceptor(
        options: CacheOptions(
          store: store,
          // El bucket puede no mandar cabeceras de caché; aquí decidimos
          // nosotros, que es una imagen que no cambia sin cambiar de URL.
          policy: CachePolicy.forceCache,
          maxStale: _vigencia,
          priority: CachePriority.low,
        ),
      ));
    }
  }

  static const Duration _vigencia = Duration(days: 30);

  final Dio _dio;
  static CacheStore? _store;

  /// Inicializa la caché. Se llama una vez en `main()`; si falla, las imágenes
  /// se siguen bajando, solo que sin persistencia.
  static Future<void> init() async {
    try {
      final dir = await getApplicationCacheDirectory();
      _store = FileCacheStore('${dir.path}/banners');
    } catch (_) {
      _store = null;
    }
  }

  /// Bytes de la imagen, o `null` si no se pudo traer.
  ///
  /// **La condición es "hay bytes", no "el código es 200"**, y esa distinción es
  /// justo la que dejó los avisos invisibles. `dio_cache_interceptor` sirve lo
  /// que guardó con **`304`** (`model/cache_response.dart`, `toResponse`), y con
  /// `CachePolicy.forceCache` ese es el camino normal y no la excepción: la
  /// primera petición va por red y devuelve 200, y todas las siguientes se
  /// resuelven en `onRequest` sin tocar la red y devuelven 304. Exigiendo un 200,
  /// cada aviso se veía **una vez** y después desaparecía durante los 30 días de
  /// `maxStale`, en las dos apps, sobreviviendo al reinicio —la caché es de
  /// disco— y sin que el usuario hubiera cerrado nada. La caché contestaba bien;
  /// era esta función la que tiraba su respuesta.
  ///
  /// `flutter_map_cache` corre sobre la misma librería, la misma política y el
  /// mismo store, y lee `response.data!` sin mirar el código: por eso los tiles
  /// del mapa llevan meses funcionando con este mismo bug al lado.
  ///
  /// De si hay algo que pintar responde el cuerpo. Un error de verdad —4xx, 5xx,
  /// timeout, sin red— no llega como un cuerpo válido con un código raro: llega
  /// como excepción de dio, al `catch`.
  ///
  /// `null` no es un error que haya que enseñar: la tarjeta se queda fuera del
  /// carrusel. Un hueco gris con un icono de imagen rota comunica menos que no
  /// mostrar nada.
  Future<Uint8List?> bytes(String url) async {
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final datos = res.data;
      if (datos == null || datos.isEmpty) {
        return null;
      }
      return Uint8List.fromList(datos);
    } catch (_) {
      return null;
    }
  }
}

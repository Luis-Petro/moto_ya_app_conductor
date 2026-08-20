import 'dart:typed_data';

import 'package:app_conductor/data/services/banner_image_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests de la clase que dejó los banners invisibles.
///
/// No tenía ninguno, y ahí estuvo la gracia: los tests del carrusel la mockean
/// con un PNG que siempre llega, así que ninguno podía descubrir que la
/// respuesta real de una caché no es un 200.
///
/// El síntoma era que un aviso se veía **una vez** y después no volvía —ni
/// cambiando de pestaña, ni volviendo del segundo plano, ni reiniciando la app,
/// en las dos apps— porque `dio_cache_interceptor` sirve lo que guardó con
/// `statusCode: 304` y `bytes()` exigía 200.

/// Dio que resuelve la petición **sin red**, igual que hace
/// `dio_cache_interceptor` al servir desde disco: con `handler.resolve`, que no
/// pasa por `validateStatus`.
///
/// Reproducirlo así es el punto del test. Un adaptador HTTP falso que devolviera
/// 304 no vale: dio lo trataría como error de estado y el test acabaría
/// comprobando el `catch`, que es otro camino y ya funcionaba.
Dio _dioQueResuelve({int? statusCode, List<int>? datos}) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) => handler.resolve(
      Response<List<int>>(
        requestOptions: options,
        statusCode: statusCode,
        data: datos,
      ),
    ),
  ));
  return dio;
}

/// Dio que rechaza, como un timeout o un teléfono sin cobertura.
Dio _dioQueFalla() {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) => handler.reject(
      DioException.connectionError(
        requestOptions: options,
        reason: 'sin cobertura',
      ),
    ),
  ));
  return dio;
}

const _url = 'https://archivos.zumbeo.com/banners/7.webp';
final _datos = <int>[137, 80, 78, 71];

void main() {
  test('una respuesta servida desde la caché (304) devuelve los bytes', () async {
    final store = BannerImageStore(dio: _dioQueResuelve(statusCode: 304, datos: _datos));

    // Este es el test que faltaba. Con la condición anterior devolvía `null` y
    // el aviso salía del carrusel durante los 30 días de `maxStale`.
    expect(await store.bytes(_url), Uint8List.fromList(_datos));
  });

  test('una respuesta de red (200) devuelve los bytes', () async {
    final store = BannerImageStore(dio: _dioQueResuelve(statusCode: 200, datos: _datos));

    expect(await store.bytes(_url), Uint8List.fromList(_datos));
  });

  test('sin código de estado, lo que decide es el cuerpo', () async {
    final store = BannerImageStore(dio: _dioQueResuelve(datos: _datos));

    expect(await store.bytes(_url), Uint8List.fromList(_datos));
  });

  test('un cuerpo vacío no es una imagen', () async {
    final store = BannerImageStore(
        dio: _dioQueResuelve(statusCode: 200, datos: const <int>[]));

    expect(await store.bytes(_url), isNull);
  });

  test('sin cuerpo no hay nada que pintar', () async {
    final store = BannerImageStore(dio: _dioQueResuelve(statusCode: 200));

    expect(await store.bytes(_url), isNull);
  });

  test('un fallo de red devuelve null en vez de lanzar', () async {
    // La franja no puede estorbar el uso normal de la app: el aviso se queda
    // fuera del carrusel y no aparece ningún error en pantalla.
    final store = BannerImageStore(dio: _dioQueFalla());

    expect(await store.bytes(_url), isNull);
  });
}

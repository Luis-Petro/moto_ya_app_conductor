import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda del **cacheo de tiles**: garantiza que ninguna pantalla pueda pedir
/// tiles por fuera de la caché de disco.
///
/// No es un test de estilo. El proveedor de tiles tiene **cuota diaria** (3.000
/// créditos, 0,25 por tile) y limita las peticiones por segundo. Un `TileLayer`
/// construido a mano en una pantalla nueva no daría error, no se vería en una
/// revisión y gastaría cuota de todas las instalaciones a la vez — hasta que un
/// día el mapa saliera gris para todo el municipio y sin ningún mensaje.
///
/// Por eso hay un único sitio donde se construye la capa (`osmTileLayer()`), con
/// el `CachedTileProvider` dentro, y este test lo vigila leyendo el código.
void main() {
  const rutaCapa = 'lib/ui/core/widgets/map_widgets.dart';

  List<File> fuentesDart() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String rutaNormalizada(File f) => f.path.replaceAll(r'\', '/');

  // El límite de palabra es lo que distingue construir `TileLayer(` de llamar a
  // `osmTileLayer()`, que lo contiene como sufijo.
  final construyeCapa = RegExp(r'(^|[^A-Za-z0-9_])TileLayer\(', multiLine: true);

  test('solo osmTileLayer() construye un TileLayer', () {
    final infractores = <String>[];
    for (final f in fuentesDart()) {
      final ruta = rutaNormalizada(f);
      if (ruta.endsWith(rutaCapa)) continue;
      if (construyeCapa.hasMatch(f.readAsStringSync())) infractores.add(ruta);
    }

    expect(
      infractores,
      isEmpty,
      reason: 'Estos archivos construyen una capa de tiles por su cuenta y se '
          'saltan la caché de disco. Usa osmTileLayer().',
    );
  });

  test('la capa de tiles va contra la caché de disco', () {
    final capa = File(rutaCapa).readAsStringSync();

    expect(capa.contains('CachedTileProvider'), isTrue);
    expect(capa.contains('MapTileCache.store'), isTrue);
    // Sin esto se pide un anillo de tiles alrededor de la pantalla: ~35 tiles por
    // apertura en vez de ~15, y el límite por segundo del proveedor los devuelve
    // en gris.
    expect(capa.contains('panBuffer: 0'), isTrue);
  });

  test('la caché se inicializa al arrancar la app', () {
    expect(File('lib/main.dart').readAsStringSync().contains('MapTileCache.init()'), isTrue);
  });
}

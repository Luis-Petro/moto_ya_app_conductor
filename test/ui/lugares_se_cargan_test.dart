import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda de la **carga del catálogo de lugares** en los mapas.
///
/// "A veces carga y a veces no" fue un reporte real, y su causa era una carrera:
/// la capa lee el municipio de la caché del usuario y, si todavía no ha llegado,
/// tiene que volver a mirar. Con **un solo reintento a los 2 segundos** eso no
/// era un arreglo sino una moneda al aire — un arranque en frío, una red de
/// municipio o un teléfono lento y la capa se rendía para siempre, dejando el
/// mapa sin un solo marcador, sin error y sin nada que reintentar.
///
/// En un municipio sin nomenclatura el catálogo no es decoración: es cómo la
/// gente explica dónde vive.
void main() {
  const capa = 'lib/ui/core/widgets/lugares_layer.dart';
  const servicio = 'lib/data/services/lugar_service.dart';

  test('el reintento es escalonado, no un único disparo', () {
    final src = File(capa).readAsStringSync();
    expect(src, contains('_esperas'));
    expect(
      src,
      isNot(contains('if (_reintentos == 0)')),
      reason: 'Volvió el reintento único: si el municipio tarda más que esa '
          'espera, el mapa se queda sin marcadores para siempre.',
    );
  });

  test('el reintento se cancela al salir de la pantalla', () {
    // Con un `await` suelto, salir de la pantalla dejaba la espera viva y
    // volvía sobre un State ya desmontado.
    final src = File(capa).readAsStringSync();
    expect(src, contains('Timer? _reintento'));
    expect(src, contains('_reintento?.cancel()'));
  });

  test('el servicio distingue "falló" de "no hay lugares"', () {
    // Con la misma lista vacía para las dos cosas, nada podía decidir si valía
    // la pena reintentar, y un fallo de red se veía igual que un municipio sin
    // catálogo: un mapa pelado y ni una pista.
    final src = File(servicio).readAsStringSync();
    expect(src, contains('Future<List<Lugar>?> catalogoDeMapa'));
    expect(src, contains('No se cachea el fallo'));
  });
}

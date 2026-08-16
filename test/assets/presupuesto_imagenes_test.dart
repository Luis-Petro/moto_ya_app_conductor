import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Presupuesto de peso de los assets de imagen.
///
/// Nadie mira el peso de un PNG en una revisión de código. Sin este test, el
/// siguiente asset que alguien arrastre a la carpeta devuelve el APK a los
/// 17 MB que acaba de dejar atrás, y ninguna señal lo delata: el build sigue
/// verde, la pantalla se ve igual y la descarga es un minuto más larga.
void main() {
  const topeGeneral = 300 * 1024;

  /// Los iconos son la entrada de `flutter_launcher_icons`, no algo que se
  /// pinte: se les exige más porque de ellos salen todas las densidades.
  const topeIconos = 150 * 1024;
  const iconos = {'icono.png', 'icono_foreground.png'};

  final imagenes = Directory('assets')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) {
        final n = f.uri.pathSegments.last;
        return n.endsWith('.png') || n.endsWith('.webp');
      })
      .toList();

  test('hay imágenes que revisar', () {
    // Si un renombrado de carpeta deja la lista vacía, los demás casos pasarían
    // por no tener nada que mirar. Un presupuesto que no vigila nada es peor
    // que no tenerlo, porque parece que sí.
    expect(imagenes, isNotEmpty);
  });

  test('ninguna imagen de assets pasa de su presupuesto', () {
    final excedidos = <String>[];
    for (final f in imagenes) {
      final nombre = f.uri.pathSegments.last;
      final tope = iconos.contains(nombre) ? topeIconos : topeGeneral;
      final bytes = f.lengthSync();
      if (bytes > tope) {
        excedidos.add('$nombre: ${(bytes / 1024).round()} KB '
            '(tope ${(tope / 1024).round()} KB)');
      }
    }
    expect(excedidos, isEmpty, reason: excedidos.join('\n'));
  });

  test('ninguna imagen se empaqueta en PNG y WebP a la vez', () {
    // Los assets se declaran por carpeta, así que un `.png` olvidado al lado de
    // su `.webp` no da error en ningún sitio: simplemente viaja en el APK para
    // siempre, que es justo el peso que se acaba de quitar.
    final rutas = imagenes.map((f) => f.path).toSet();
    final duplicados = [
      for (final r in rutas)
        if (r.endsWith('.webp') &&
            rutas.contains('${r.substring(0, r.length - 5)}.png'))
          r.substring(0, r.length - 5),
    ];
    expect(duplicados, isEmpty, reason: 'Sobra el .png de: ${duplicados.join(", ")}');
  });
}

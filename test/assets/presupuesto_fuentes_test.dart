import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Presupuesto de peso de la tipografía empaquetada.
///
/// La fuente propia es lo que hace que la app se vea igual en todos los
/// teléfonos, pero se paga con bytes que descarga cada instalación. Hoy son
/// 72 KB los tres pesos, subseteados al español con `tools/subsetear-fuente.py`.
///
/// El tope existe porque el fallo típico no es empaquetar una fuente pesada: es
/// añadir "por si acaso" un cuarto peso, o regenerar el subset sin los rangos y
/// meter el juego completo. Las dos cosas dejan el build verde y la pantalla
/// idéntica.
void main() {
  const topeTotal = 200 * 1024;

  /// Los tres pesos del sistema visual. Si alguien añade uno, este test le
  /// obliga a justificarlo aquí antes que en el APK.
  const esperados = {
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  };

  final dir = Directory('assets/fonts');
  final fuentes = dir.existsSync()
      ? dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.ttf'))
          .toList()
      : <File>[];

  test('la tipografía viaja en el paquete', () {
    // Sin este caso, borrar la carpeta dejaría el presupuesto en verde por no
    // tener nada que medir — y la app volvería a la fuente del fabricante sin
    // que nada lo delatara.
    expect(fuentes, isNotEmpty, reason: 'No hay ninguna fuente en assets/fonts/');
    expect(
      fuentes.map((f) => f.uri.pathSegments.last).toSet(),
      esperados,
      reason: 'Los pesos empaquetados no son los tres del sistema visual.',
    );
  });

  test('la licencia acompaña a la fuente', () {
    // SIL OFL 1.1 exige distribuir la licencia con la fuente.
    expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
  });

  test('las fuentes no pasan del presupuesto', () {
    final total = fuentes.fold<int>(0, (suma, f) => suma + f.lengthSync());
    expect(
      total,
      lessThanOrEqualTo(topeTotal),
      reason: 'assets/fonts/ pesa ${(total / 1024).round()} KB '
          '(tope ${topeTotal ~/ 1024} KB). Revisar los rangos de subsetting en '
          'tools/subsetear-fuente.py antes de subir el tope.',
    );
  });

  test('la familia está declarada en pubspec con sus tres pesos', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('family: PlusJakartaSans'), isTrue);
    for (final nombre in esperados) {
      expect(
        pubspec.contains(nombre),
        isTrue,
        reason: '$nombre está en assets/fonts/ pero no declarado en pubspec: '
            'no se empaqueta y Flutter cae a la fuente del sistema.',
      );
    }
  });
}

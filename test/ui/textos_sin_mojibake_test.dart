import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda del **encoding de los textos**: garantiza que ningún archivo de `lib/`
/// vuelva a quedar con sus acentos doblemente codificados.
///
/// No es un test de estilo. Cuando un archivo UTF-8 se relee como Latin-1/CP1252
/// y se vuelve a guardar como UTF-8, una `ó` se convierte en `Ã³` y una `—` en
/// `â€”`. Dart lee siempre las fuentes como UTF-8, así que eso no es un problema
/// de locale ni de tiempo de ejecución: son los bytes del archivo, y lo que el
/// conductor lee en pantalla es literalmente "VehÃ­culo".
///
/// Por qué un test y no una revisión de diff: en un diff estas secuencias se leen
/// como texto plausible, no rompen el análisis, no rompen el build y nadie las
/// nota. La única forma de que no vuelvan es que el build falle nombrando el
/// archivo y la línea.
///
/// Si algún día hace falta una de estas letras de verdad (un nombre propio, un
/// caso de prueba), se marca esa línea con `// mojibake-ok`.
void main() {
  /// Caracteres que **no existen** en un texto en español y que solo aparecen
  /// como primer byte de una secuencia doblemente codificada:
  /// `Ã` (0xC3), `Â` (0xC2), `â` (0xE2) y `ð` (0xF0).
  const marcadores = <String, String>{
    'Ã': 'Ã (tilde doblemente codificada: Ã³ = ó, Ã­ = í, Ã¡ = á)',
    'Â': 'Â (Â· = ·, Â¿ = ¿)',
    'â': 'â (â€” = —, â€¦ = …)',
    'ð': 'ð (ðŸ‡¨ðŸ‡´ = 🇨🇴)',
  };

  const permiso = 'mojibake-ok';

  List<File> fuentesDart() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String rutaNormalizada(File f) => f.path.replaceAll(r'\', '/');

  test('la guarda está leyendo el árbol de verdad', () {
    // Sin esto, un cambio de directorio de trabajo o un `listSync` que devuelva
    // vacío haría pasar el test en verde sin haber leído ni un archivo, que es la
    // peor forma de fallar: silenciosa y con apariencia de éxito.
    expect(fuentesDart().length, greaterThan(50));
  });

  test('ningún texto de lib/ tiene acentos doblemente codificados', () {
    final hallazgos = <String>[];

    for (final archivo in fuentesDart()) {
      final ruta = rutaNormalizada(archivo);
      final lineas = archivo.readAsLinesSync();

      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        if (linea.contains(permiso)) continue;

        for (final entrada in marcadores.entries) {
          if (linea.contains(entrada.key)) {
            hallazgos.add('$ruta:${i + 1} — ${entrada.value}\n    ${linea.trim()}');
            break;
          }
        }
      }
    }

    expect(
      hallazgos,
      isEmpty,
      reason: 'Estos textos están doblemente codificados y el usuario los lee '
          'roto en pantalla. Recupera el acento real (no borres la letra):\n'
          '${hallazgos.join('\n')}',
    );
  });
}

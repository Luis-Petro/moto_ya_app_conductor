import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El backend solo acepta JPG, PNG y WebP: comprueba el contenido, no el nombre.
///
/// Lo que impide que llegue un HEIC de iPhone —que ningún navegador pinta, así
/// que la foto quedaría rota en el panel sin ningún error— es que **todas** las
/// llamadas a `pickImage` pasan `imageQuality`. Con ese parámetro,
/// `image_picker` decodifica y reencoda a JPEG en las dos plataformas; sin él,
/// devuelve el archivo original tal cual, con el formato que tuviera la galería.
///
/// Es una propiedad de los sitios de llamada, no del plugin, y por eso se vigila
/// aquí: una pantalla nueva que abra la galería sin `imageQuality` no da ningún
/// error, funciona en Android y falla solo en los iPhone, meses después.
void main() {
  final fuentes = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => (ruta: f.path, texto: f.readAsStringSync()))
      .where((f) => f.texto.contains('pickImage('))
      .toList();

  test('hay llamadas a pickImage que vigilar', () {
    expect(fuentes, isNotEmpty);
  });

  for (final fuente in fuentes) {
    test('${fuente.ruta} pide siempre imageQuality', () {
      // Una por cada apertura de cámara o galería del archivo.
      final aperturas = 'pickImage('.allMatches(fuente.texto).length;
      final calidades = 'imageQuality:'.allMatches(fuente.texto).length;

      expect(
        calidades,
        greaterThanOrEqualTo(aperturas),
        reason:
            'sin imageQuality, image_picker entrega el archivo original: en un '
            'iPhone eso es HEIC y el backend lo rechaza con 400',
      );
    });
  }
}

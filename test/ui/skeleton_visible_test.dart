import 'dart:math' as math;
import 'dart:ui';

import 'package:app_conductor/ui/core/theme/app_colors.dart';
import 'package:app_conductor/ui/core/widgets/skeleton.dart';
import 'package:flutter_test/flutter_test.dart';

/// El esqueleto de carga tiene que **verse**.
///
/// El comentario de `AppColors.skeleton` afirmaba que este test existía y fijaba
/// el suelo de 1,4:1. No existía: la regla llevaba viviendo de una afirmación
/// que nadie había comprobado, que es la forma en que un valor medido se acaba
/// perdiendo en la siguiente copia.
///
/// El motivo de que el conductor tenga su propio valor: el bloque se pintaba con
/// `AppColors.line` (#E3E8EE) sobre `background` (#F7F8FA) y daba **1,06:1** en
/// el punto apagado del ciclo — al sol, en un celular de gama media, una pantalla
/// en blanco. Y así llegó el reporte.
///
/// Por eso este archivo importa: **`app_cliente` usa `#E8ECF1` para lo mismo**, y
/// aquí daría 1,07:1. Este change consiste precisamente en copiar cosas del
/// cliente, así que este test es lo único que impide que una copia por inercia
/// devuelva la pantalla en blanco sin que nada falle.
double _luminancia(Color c) {
  double canal(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

double _contraste(Color a, Color b) {
  final la = _luminancia(a);
  final lb = _luminancia(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  /// Suelo medido. Por debajo de esto el bloque deja de leerse como "aquí va a
  /// llegar algo" y pasa a leerse como pantalla vacía.
  const suelo = 1.4;

  /// Los dos extremos del degradado que barre el bloque. **Los dos** tienen que
  /// pasar: el brillo no es un detalle decorativo, es una banda que recorre todo
  /// el bloque, y si se funde con el fondo lo que se ve es un trozo de pantalla
  /// que falta.
  final extremos = <String, Color>{
    'relleno': Skeleton.relleno,
    'brillo': Skeleton.brillo,
  };

  for (final extremo in extremos.entries) {
    test('el ${extremo.key} del esqueleto se ve sobre el fondo', () {
      final ratio = _contraste(extremo.value, AppColors.background);
      expect(
        ratio,
        greaterThanOrEqualTo(suelo),
        reason: 'El ${extremo.key} del bloque de carga da '
            '${ratio.toStringAsFixed(2)}:1 contra el fondo (mínimo $suelo:1). '
            'Aclararlo deja la pantalla en blanco al sol.',
      );
    });
  }

  test('el brillo es más claro que el relleno', () {
    // Contraparte del caso anterior: los dos podrían pasar el suelo siendo el
    // mismo color, y entonces el barrido no se vería aunque el test estuviera
    // verde. Lo que se comprueba aquí es que hay animación que ver.
    expect(
      _luminancia(Skeleton.brillo),
      greaterThan(_luminancia(Skeleton.relleno)),
    );
  });

  test('los colores del esqueleto salen de los tokens, no de literales', () {
    // Sin esto, `Skeleton.relleno` podría dejar de ser `AppColors.skeleton` y
    // los casos de arriba seguirían en verde midiendo colores que la pantalla
    // ya no pinta.
    expect(Skeleton.relleno, AppColors.skeleton);
    expect(Skeleton.brillo, AppColors.skeletonHighlight);
  });

  test('los grises del cliente no servirían aquí', () {
    // Este caso no vigila el código: vigila la tentación. `app_cliente` usa
    // #E8ECF1 y #F4F6F9 para lo mismo, y unificar "porque son la misma marca"
    // es la forma exacta en que estos valores se pierden. El segundo es el que
    // más engaña: es casi el color del fondo, así que la banda de brillo
    // desaparece — en el cliente es un bache local, aquí sería un hueco al sol.
    for (final gris in {
      'skeleton': const Color(0xFFE8ECF1),
      'skeletonHighlight': const Color(0xFFF4F6F9),
    }.entries) {
      expect(
        _contraste(gris.value, AppColors.background),
        lessThan(suelo),
        reason: 'Si el ${gris.key} del cliente ya pasara el suelo, la '
            'divergencia sobraría: revisar los dos tokens juntos.',
      );
    }
  });
}

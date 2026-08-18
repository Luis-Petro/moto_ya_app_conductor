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

/// Color efectivo de un bloque translúcido pintado sobre un fondo opaco.
/// El `FadeTransition` del esqueleto no aclara el color: lo **mezcla** con lo
/// que tiene detrás, y es esa mezcla la que hay que medir.
Color _sobre(Color frente, Color fondo, double opacidad) => Color.fromARGB(
      255,
      (frente.r * 255 * opacidad + fondo.r * 255 * (1 - opacidad)).round(),
      (frente.g * 255 * opacidad + fondo.g * 255 * (1 - opacidad)).round(),
      (frente.b * 255 * opacidad + fondo.b * 255 * (1 - opacidad)).round(),
    );

void main() {
  /// Suelo medido. Por debajo de esto el bloque deja de leerse como "aquí va a
  /// llegar algo" y pasa a leerse como pantalla vacía.
  const suelo = 1.4;

  test('el esqueleto se ve en el punto más apagado de su ciclo', () {
    // Es el peor caso del ciclo, así que es el único que hace falta comprobar:
    // si pasa apagado, pasa encendido.
    final apagado = _sobre(
      Skeleton.relleno,
      AppColors.background,
      Skeleton.opacidadMinima,
    );
    final ratio = _contraste(apagado, AppColors.background);

    expect(
      ratio,
      greaterThanOrEqualTo(suelo),
      reason: 'El bloque de carga da ${ratio.toStringAsFixed(2)}:1 contra el '
          'fondo en el punto apagado del ciclo (mínimo $suelo:1). Aclarar el '
          'relleno o bajar `opacidadMinima` deja la pantalla en blanco al sol.',
    );
  });

  test('el esqueleto se ve también a opacidad plena', () {
    final ratio = _contraste(Skeleton.relleno, AppColors.background);
    expect(ratio, greaterThanOrEqualTo(suelo));
  });

  test('el relleno del esqueleto sale del token, no de un literal', () {
    // Contraparte del caso anterior. Sin ella, `Skeleton.relleno` podría dejar
    // de ser `AppColors.skeleton` y los dos casos de arriba seguirían en verde
    // midiendo un color que la pantalla ya no pinta.
    expect(Skeleton.relleno, AppColors.skeleton);
  });

  test('el gris del cliente no serviría aquí', () {
    // Este caso no vigila el código: vigila la tentación. `app_cliente` usa
    // #E8ECF1 para el mismo bloque y unificar "porque son la misma marca" es la
    // forma exacta en que este valor se pierde. Si algún día ese gris pasa el
    // suelo, este caso se pone rojo y la unificación deja de ser un riesgo.
    const grisDelCliente = Color(0xFFE8ECF1);
    final ratio = _contraste(
      _sobre(grisDelCliente, AppColors.background, Skeleton.opacidadMinima),
      AppColors.background,
    );
    expect(
      ratio,
      lessThan(suelo),
      reason: 'Si el gris del cliente ya pasara el suelo, la divergencia de '
          '`AppColors.skeleton` sobraría: revisar los dos tokens juntos.',
    );
  });
}

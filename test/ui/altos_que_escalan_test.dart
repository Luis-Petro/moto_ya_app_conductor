import 'dart:io';

import 'package:app_conductor/ui/core/theme/app_spacing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un alto que contiene texto **no puede ser una constante**.
///
/// El carrusel de avisos del Inicio vive dentro de un `PageView`, que necesita
/// saber cuánto mide su página. Ese alto era `132.0` a secas: con la escala de
/// texto del sistema al 130 % el contenido de la tarjeta crecía y la caja no, y
/// la tarjeta desbordaba con la franja amarilla y negra. No da error, no se ve
/// en una revisión de código y solo aparece en el teléfono de quien necesita el
/// texto grande.
///
/// Este archivo es la **contraparte** del arreglo. Un test que solo comprobara
/// que la tarjeta mide 132 seguiría en verde vigilando una constante arbitraria;
/// lo que hay que fijar es de dónde sale el número.
void main() {
  final inicio = File(
    'lib/ui/features/inicio/inicio_screen.dart',
  ).readAsStringSync();

  test('el alto de la tarjeta de aviso sale de la escala de texto', () {
    expect(
      inicio,
      contains('MediaQuery.textScalerOf(context).scale('),
      reason: 'El alto del carrusel volvió a ser una constante: con la escala '
          'al 130 % la tarjeta desborda.',
    );
    // Y se usa, no solo se declara.
    expect(inicio, contains('height: _alto(context)'));
  });

  test('solo se escala la parte que depende del texto', () {
    // El relleno de la tarjeta no crece con la letra. Escalarlo también no
    // rompe nada, pero engorda la tarjeta sin motivo y se come el mapa de
    // demanda, que es lo que este carrusel ya estaba empujando fuera.
    expect(inicio, contains('_altoBase - _altoNoEscalable'));
    expect(
      inicio,
      contains('_altoNoEscalable = 2 * AppSpacing.lg'),
      reason: 'La parte no escalable tiene que ser el relleno real de la '
          'tarjeta, no un número suelto.',
    );
  });

  test('el mínimo táctil sigue siendo el de la escala central', () {
    // Contraparte del contraparte. Varias medidas de la app se derivan de
    // `AppSpacing.minTouchTarget`; si alguien lo bajara, todas las
    // comprobaciones de área táctil seguirían en verde midiendo un número más
    // pequeño. 48 cubre Android (48dp) e iOS (44pt).
    expect(AppSpacing.minTouchTarget, greaterThanOrEqualTo(48));
  });
}

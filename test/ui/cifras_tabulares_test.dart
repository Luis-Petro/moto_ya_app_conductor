import 'dart:io';

import 'package:app_conductor/ui/core/theme/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las cifras de dinero no cambian de ancho al cambiar de valor.
///
/// Sin figuras tabulares, el `1` es más estrecho que el `7` y un valor que se
/// actualiza en vivo —una contrapropuesta que entra mientras el cliente mira la
/// pantalla— desplaza lateralmente todo lo que tiene al lado. Se nota como un
/// tirón y hace que la app parezca inestable justo en el momento en que se está
/// decidiendo cuánto pagar.
///
/// El test carga la **fuente real** a propósito. Por defecto `flutter_test`
/// sustituye toda la tipografía por Ahem, cuyos glifos ya son todos del mismo
/// ancho: mediría siempre igual y certificaría el caso contrario al que se
/// quiere comprobar.
///
/// Comprueba además, de paso, que el subsetting no se comió la feature `tnum`
/// (ver `tools/subsetear-fuente.py`): si se cae, las cifras se siguen viendo
/// bien y nada falla — solo vuelven a bailar.
void main() {
  setUpAll(() async {
    final loader = FontLoader(AppText.familia);
    for (final peso in ['Regular', 'SemiBold', 'ExtraBold']) {
      final bytes = File('assets/fonts/PlusJakartaSans-$peso.ttf').readAsBytesSync();
      loader.addFont(Future.value(bytes.buffer.asByteData()));
    }
    await loader.load();
  });

  Future<double> anchoDe(WidgetTester tester, String texto, TextStyle estilo) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text(texto, style: estilo)),
      ),
    );
    return tester.getSize(find.text(texto)).width;
  }

  // Todos los dígitos, en dos combinaciones que con figuras proporcionales
  // darían anchos muy distintos: el 1 es el glifo más estrecho y el 0 de los
  // más anchos.
  const a = r'$ 11.111';
  const b = r'$ 70.000';

  testWidgets('la cifra destacada no cambia de ancho al cambiar de valor',
      (tester) async {
    final anchoA = await anchoDe(tester, a, AppText.money);
    final anchoB = await anchoDe(tester, b, AppText.money);
    expect(anchoA, closeTo(anchoB, 0.5),
        reason: 'AppText.money perdió las figuras tabulares.');
  });

  testWidgets('la cifra de lista tampoco', (tester) async {
    final anchoA = await anchoDe(tester, a, AppText.moneySm);
    final anchoB = await anchoDe(tester, b, AppText.moneySm);
    expect(anchoA, closeTo(anchoB, 0.5),
        reason: 'AppText.moneySm perdió las figuras tabulares.');
  });

  test('los roles de dinero piden las figuras tabulares explícitamente', () {
    // Los dos casos de arriba pasan hoy incluso sin `tnum`: los dígitos de
    // Plus Jakarta Sans ya son de ancho fijo de fábrica. Es decir, la medida
    // sola **no** demuestra que la intención esté declarada, y el día que se
    // cambie de tipografía —o que un subset la deje sin la feature— pasaría
    // igual mientras las cifras vuelven a bailar.
    //
    // Por eso el rol lo pide explícitamente y esto lo comprueba: la medida
    // vigila el resultado, este caso vigila que no dependa de la suerte.
    for (final rol in {'money': AppText.money, 'moneySm': AppText.moneySm}.entries) {
      expect(
        rol.value.fontFeatures?.map((f) => f.feature),
        contains('tnum'),
        reason: 'AppText.${rol.key} debe declarar FontFeature.tabularFigures().',
      );
    }
  });
}

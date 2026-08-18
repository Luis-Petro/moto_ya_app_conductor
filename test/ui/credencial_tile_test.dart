import 'package:app_conductor/ui/core/theme/app_theme.dart';
import 'package:app_conductor/ui/core/widgets/credencial_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// El correo y el celular del perfil no se parten en varios renglones.
///
/// El fallo que arregla: el icono, la etiqueta, el valor, el distintivo de
/// verificación y **dos botones** vivían en un solo `Row`. En un teléfono
/// estrecho no cabían y lo que cedía era el valor, que se partía carácter a
/// carácter: el celular salía como "300 / 1234 / 567" y el correo como
/// ".co / m". Un dato así no se puede ni leer ni dictar por teléfono, y era
/// justo la pantalla donde alguien va a comprobar que su contacto está bien.
///
/// Nada de esto daba error ni se veía en una revisión de código: el texto
/// simplemente encuentra dónde partirse y sigue. Por eso hay test.
void main() {
  /// El ancho más estrecho que se soporta. En 320 dp caben un iPhone SE y buena
  /// parte de la gama baja Android que es el parque real.
  const anchoEstrecho = Size(320, 640);

  Widget montar(Widget hijo, {double escalaTexto = 1.0}) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(escalaTexto)),
          child: Padding(padding: const EdgeInsets.all(16), child: hijo),
        ),
      ),
    );
  }

  CredencialTile tile({
    String? valor,
    bool? verificado,
    String etiqueta = 'Celular',
  }) =>
      CredencialTile(
        etiqueta: etiqueta,
        icono: Icons.phone_outlined,
        vacio: 'Sin celular',
        valor: valor,
        verificado: verificado,
        onCambiar: () {},
        onVerificar: () {},
      );

  Future<void> enPantallaEstrecha(
    WidgetTester tester,
    Widget hijo, {
    double escalaTexto = 1.0,
  }) async {
    tester.view.physicalSize = anchoEstrecho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(montar(hijo, escalaTexto: escalaTexto));
    await tester.pumpAndSettle();
  }

  /// Alto que ocupa el valor ya maquetado. Un renglón de más se ve aquí como
  /// un alto que casi se dobla — que es exactamente el fallo que se vigila.
  ///
  /// Se mide el alto y no el número de renglones porque `RenderParagraph` no
  /// expone las métricas de línea en esta versión de Flutter, y un test no
  /// debería depender de un detalle interno del framework para comprobar algo
  /// tan visible como si un texto cabe.
  double altoDelValor(WidgetTester tester, String texto) =>
      tester.getSize(find.text(texto)).height;

  /// Referencia de un renglón, en las mismas condiciones.
  Future<double> altoDeUnRenglon(WidgetTester tester,
      {double escalaTexto = 1.0}) async {
    await enPantallaEstrecha(tester, tile(valor: '3', verificado: false),
        escalaTexto: escalaTexto);
    return altoDelValor(tester, '3');
  }

  testWidgets('el celular ocupa un solo renglón a 320 dp', (tester) async {
    final unRenglon = await altoDeUnRenglon(tester);
    await enPantallaEstrecha(
      tester,
      tile(valor: '300 1234 567', verificado: false),
    );
    expect(altoDelValor(tester, '300 1234 567'), unRenglon);
  });

  testWidgets('un correo largo se recorta, no se parte', (tester) async {
    const largo = 'unnombredecorreobastantelargo@ejemplo.com';
    final unRenglon = await altoDeUnRenglon(tester);
    await enPantallaEstrecha(
      tester,
      tile(valor: largo, verificado: false, etiqueta: 'Correo'),
    );
    expect(altoDelValor(tester, largo), unRenglon);
    // Y se recorta de verdad, en vez de encogerse hasta ser ilegible.
    final render = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(largo), matching: find.byType(RichText)),
    );
    expect(render.didExceedMaxLines, isTrue);
  });

  testWidgets('sigue en un renglón con la escala de texto al 130 %',
      (tester) async {
    final unRenglon = await altoDeUnRenglon(tester, escalaTexto: 1.3);
    await enPantallaEstrecha(
      tester,
      tile(valor: '300 1234 567', verificado: false),
      escalaTexto: 1.3,
    );
    expect(altoDelValor(tester, '300 1234 567'), unRenglon);
  });

  testWidgets('no desborda en ninguno de los dos estados', (tester) async {
    // `pumpWidget` deja el desborde en `takeException`: si la fila se sale por
    // los lados, esto lo caza sin depender de mirar una captura.
    for (final verificado in [true, false]) {
      await enPantallaEstrecha(
        tester,
        tile(valor: 'marta.gomez.perez@ejemplo.com', verificado: verificado),
        escalaTexto: 1.3,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('"Verificar" solo aparece si falta verificar', (tester) async {
    await enPantallaEstrecha(tester, tile(valor: '300 1234 567', verificado: false));
    expect(find.text('Verificar'), findsOneWidget);
    expect(find.text('Sin verificar'), findsOneWidget);

    await enPantallaEstrecha(tester, tile(valor: '300 1234 567', verificado: true));
    expect(find.text('Verificar'), findsNothing);
    expect(find.text('Verificado'), findsOneWidget);
  });

  testWidgets('sin dato ofrece agregarlo y no habla de verificación',
      (tester) async {
    await enPantallaEstrecha(tester, tile());
    expect(find.text('Sin celular'), findsOneWidget);
    expect(find.text('Agregar'), findsOneWidget);
    expect(find.text('Verificar'), findsNothing);
    expect(find.text('Sin verificar'), findsNothing);
  });
}

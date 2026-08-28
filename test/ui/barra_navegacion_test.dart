import 'dart:io';

import 'package:app_conductor/ui/core/theme/app_colors.dart';
import 'package:app_conductor/ui/core/theme/app_text.dart';
import 'package:app_conductor/ui/core/theme/app_theme.dart';
import 'package:app_conductor/ui/core/widgets/barra_navegacion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La barra inferior es el sitio más tocado de la app, y hasta ahora era el
/// menos vigilado: cada shell montaba el suyo y las dos apps se habían separado
/// sin que nada lo delatara (el de cliente tenía píldora, háptico y sombra; el
/// de conductor, ninguna de las tres).
///
/// Cada caso de aquí fija una regla que **no se ve en una revisión de código**:
/// un `selectedItemColor` con el naranja de marca se lee perfectamente en el
/// diff y es el que no se lee en el teléfono.
const _destinos = [
  DestinoNav(
    icono: Icons.home_outlined,
    iconoActivo: Icons.home_rounded,
    etiqueta: 'Inicio',
  ),
  DestinoNav(
    icono: Icons.receipt_long_outlined,
    iconoActivo: Icons.receipt_long_rounded,
    etiqueta: 'Pedidos',
  ),
  DestinoNav(
    icono: Icons.person_outline_rounded,
    iconoActivo: Icons.person_rounded,
    etiqueta: 'Perfil',
  ),
];

/// Monta la barra con estado propio para poder cambiar de pestaña de verdad.
Future<void> _montar(
  WidgetTester tester, {
  int inicial = 0,
  List<DestinoNav> destinos = _destinos,
}) {
  var indice = inicial;
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: StatefulBuilder(
      builder: (context, setState) => Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: BarraNavegacion(
          indice: indice,
          destinos: destinos,
          onSeleccion: (i) => setState(() => indice = i),
        ),
      ),
    ),
  ));
}

BoxDecoration _decoracionDe(WidgetTester tester, Finder finder) =>
    tester.widget<Container>(finder).decoration! as BoxDecoration;

void main() {
  testWidgets('la pestaña activa se distingue por forma, no solo por color',
      (tester) async {
    await _montar(tester);

    // Icono relleno solo en la activa; las demás en contorno.
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);

    // Y una sola píldora, la de la activa. Es la señal que sigue funcionando
    // para quien no separa el naranja del gris.
    final pildoras = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .where((c) =>
            (c.decoration as BoxDecoration?)?.color == AppColors.primarySurface)
        .length;
    expect(pildoras, 1,
        reason: 'La pestaña activa se quedó sin píldora: vuelve a distinguirse '
            'solo por color.');
  });

  testWidgets('el color de la pestaña activa no es el naranja de relleno',
      (tester) async {
    await _montar(tester);
    final tema = Theme.of(tester.element(find.byType(BarraNavegacion)))
        .bottomNavigationBarTheme;

    expect(
      tema.selectedItemColor,
      AppColors.primaryInk,
      reason: '`primary` sobre blanco da 3,17:1 y sobre la píldora 2,78:1. Ver '
          '`contraste_test.dart`: en fondo claro, texto e iconos van en '
          '`primaryInk`.',
    );
    expect(tema.unselectedItemColor, AppColors.inkMuted);
    expect(
      tema.selectedLabelStyle?.fontWeight,
      AppText.fuerte,
      reason: 'La etiqueta activa también engorda: tercera señal, '
          'independiente del color y de la forma del icono.',
    );
  });

  testWidgets('la barra se separa del contenido con borde y sombra',
      (tester) async {
    await _montar(tester);
    final deco = _decoracionDe(
      tester,
      find
          .descendant(
            of: find.byType(BarraNavegacion),
            matching: find.byType(Container),
          )
          .first,
    );

    // Los dos juntos, igual que `MotoCard`: la sombra sola desaparece cuando lo
    // que hay encima es una tarjeta blanca; el borde solo, a pleno sol.
    expect(deco.border, isNotNull, reason: 'Falta la línea de separación.');
    expect(deco.boxShadow, isNotEmpty, reason: 'Falta la sombra hacia arriba.');
    expect(
      deco.boxShadow!.first.offset.dy,
      lessThan(0),
      reason: 'La sombra va hacia arriba: es la única dirección en la que hay '
          'contenido del que separarse.',
    );
  });

  testWidgets('cambiar de pestaña se anima, no salta', (tester) async {
    await _montar(tester);
    await tester.tap(find.text('Perfil'));

    // A mitad del cruce conviven el icono que se va y el que llega. Sin la
    // animación, en este fotograma solo habría uno.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets('el punto de aviso se anuncia, no solo se pinta', (tester) async {
    final semantica = tester.ensureSemantics();
    const conAviso = [
      DestinoNav(
        icono: Icons.home_outlined,
        iconoActivo: Icons.home_rounded,
        etiqueta: 'Inicio',
      ),
      DestinoNav(
        icono: Icons.account_balance_wallet_outlined,
        iconoActivo: Icons.account_balance_wallet_rounded,
        etiqueta: 'Billetera',
        aviso: 'Bloqueado por deuda',
      ),
    ];

    await _montar(tester, destinos: conAviso);
    // Un punto de color no le dice nada a un lector de pantalla, y quien lo usa
    // es exactamente quien no puede verlo.
    expect(find.bySemanticsLabel(RegExp('Bloqueado por deuda')), findsWidgets);

    await _montar(tester, destinos: _destinos);
    expect(find.bySemanticsLabel(RegExp('Bloqueado por deuda')), findsNothing);
    semantica.dispose();
  });

  test('la barra tiene cuatro destinos y no pasa de cinco', () {
    // Dos afirmaciones, y la segunda es la regla: más de cinco estrecha cada
    // objetivo por debajo del pulgar y convierte elegir en adivinar. La primera
    // es el inventario de hoy —Inicio · Billetera · Historial · Perfil— y está
    // para que añadir una quinta pestaña sea una decisión y no un descuido: con
    // solo el tope, la quinta entra sin que nada se entere.
    //
    // Se cuenta sobre el shell real y no sobre una constante del test, que es lo
    // único que puede quedarse desactualizado sin que se note.
    final shells = Directory('lib/ui/features/shell')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(shells, isNotEmpty, reason: '¿Se movió la carpeta del shell?');

    for (final f in shells) {
      final pestanas = 'DestinoNav('.allMatches(f.readAsStringSync()).length;
      expect(pestanas, lessThanOrEqualTo(5),
          reason: '${f.path}: $pestanas pestañas. El tope es cinco.');
      expect(pestanas, 4,
          reason: '${f.path}: $pestanas pestañas. Si el cambio es intencionado, '
              'actualiza este número; sigue habiendo sitio hasta cinco.');
    }
  });
}

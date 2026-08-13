import 'package:app_conductor/ui/core/widgets/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El avatar nunca puede quedar en blanco.
///
/// `InitialsAvatar` pinta la foto con `foregroundImage`, así que las iniciales
/// quedan debajo como respaldo natural del `CircleAvatar`. La foto de perfil
/// usaba `backgroundImage` sin child y una URL vencida dejaba un círculo vacío.
/// En `flutter test` toda petición de red falla, así que montar el widget con
/// una URL ejercita justo ese camino.
void main() {
  Future<void> montar(WidgetTester tester, Widget hijo) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: hijo))));
    await tester.pumpAndSettle();
  }

  testWidgets('con una URL que falla muestra las iniciales', (tester) async {
    await montar(
      tester,
      const InitialsAvatar(
        initials: 'JH',
        imageUrl: 'https://ejemplo.invalido/f.jpg',
        radius: 40,
      ),
    );

    expect(find.text('JH'), findsOneWidget);
  });

  testWidgets('sin URL muestra las iniciales', (tester) async {
    await montar(tester, const InitialsAvatar(initials: 'MP', radius: 40));

    expect(find.text('MP'), findsOneWidget);
  });
}

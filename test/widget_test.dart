import 'package:app_conductor/ui/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PrimaryButton muestra el label y dispara onPressed',
      (tester) async {
    var pulsado = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PrimaryButton(
          label: 'Buscar conductor',
          onPressed: () => pulsado = true,
        ),
      ),
    ));

    expect(find.text('Buscar conductor'), findsOneWidget);
    await tester.tap(find.byType(PrimaryButton));
    expect(pulsado, isTrue);
  });

  testWidgets('PrimaryButton en loading no dispara onPressed', (tester) async {
    var pulsado = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PrimaryButton(
          label: 'Cargando',
          loading: true,
          onPressed: () => pulsado = true,
        ),
      ),
    ));

    await tester.tap(find.byType(PrimaryButton));
    expect(pulsado, isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}


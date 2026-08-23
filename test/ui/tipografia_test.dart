import 'dart:io';

import 'package:app_conductor/ui/core/theme/app_text.dart';
import 'package:app_conductor/ui/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Que la fuente empaquetada sea **la que se pinta**.
///
/// `ThemeData(fontFamily:)` aplica Plus Jakarta al `textTheme`, pero justo
/// despuÃ©s `AppTheme.light` sustituye once roles por los estilos de `AppText`,
/// que no declaran familia. Entre ellos `bodyMedium`, que es el
/// `DefaultTextStyle` del que hereda **todo** `Text` de la app: la fuente
/// viajaba en el APK â€”con su peso, su script de subsetting y su test de
/// presupuestoâ€” y no la usaba nadie. En Android se veÃ­a la del fabricante, que
/// es exactamente lo que empaquetarla venÃ­a a evitar.
///
/// No falla nada, no hay aviso, y una captura de pantalla tampoco lo delata:
/// solo se ve midiendo el ancho de un texto. De ahÃ­ este test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader(AppText.familia);
    for (final peso in ['Regular', 'SemiBold', 'ExtraBold']) {
      loader.addFont(File('assets/fonts/PlusJakartaSans-$peso.ttf')
          .readAsBytes()
          .then((b) => ByteData.view(Uint8List.fromList(b).buffer)));
    }
    await loader.load();
  });

  test('todos los roles del tema declaran la familia empaquetada', () {
    final t = AppTheme.light.textTheme;
    final roles = <String, TextStyle?>{
      'displaySmall': t.displaySmall,
      'headlineSmall': t.headlineSmall,
      'titleLarge': t.titleLarge,
      'titleMedium': t.titleMedium,
      'titleSmall': t.titleSmall,
      'bodyLarge': t.bodyLarge,
      'bodyMedium': t.bodyMedium,
      'bodySmall': t.bodySmall,
      'labelLarge': t.labelLarge,
      'labelMedium': t.labelMedium,
      'labelSmall': t.labelSmall,
    };
    roles.forEach((nombre, estilo) {
      expect(estilo?.fontFamily, AppText.familia,
          reason: '$nombre se quedÃ³ sin familia: heredarÃ¡ la del sistema.');
    });
  });

  testWidgets('un texto corriente se pinta con la fuente empaquetada, no con '
      'la del sistema', (tester) async {
    // La comprobaciÃ³n de verdad: la familia declarada en el tema podrÃ­a estar
    // bien y aun asÃ­ no llegar al `Text`, porque lo que hereda es el
    // `DefaultTextStyle`. Se mide, no se lee.
    //
    // La fuente de las pruebas da a cada glifo el ancho de su altura, asÃ­ que
    // una eme y una i miden lo mismo. Con una fuente real, no.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MMMMMMMMMM', style: AppText.body),
            Text('iiiiiiiiii', style: AppText.body),
          ],
        ),
      ),
    ));

    final anchas = tester.getSize(find.text('MMMMMMMMMM')).width;
    final estrechas = tester.getSize(find.text('iiiiiiiiii')).width;
    expect(anchas, greaterThan(estrechas * 2),
        reason: 'Los glifos miden todos lo mismo: se estÃ¡ pintando la fuente '
            'de respaldo, no ${AppText.familia}.');
  });
}


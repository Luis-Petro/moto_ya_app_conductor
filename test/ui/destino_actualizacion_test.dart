import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_conductor/ui/core/widgets/banner_version.dart';

void main() {
  group('destinoActualizacion', () {
    test('en Android manda a Google Play', () {
      final d = destinoActualizacion(
        plataforma: TargetPlatform.android,
        playStoreUrl: 'https://play.google.com/store/apps/details?id=x',
        appStoreUrl: 'https://apps.apple.com/co/app/motoya/id1',
      );

      expect(d!.url, startsWith('https://play.google.com/'));
      expect(d.icono, Icons.shop);
    });

    test('en iOS manda al App Store', () {
      final d = destinoActualizacion(
        plataforma: TargetPlatform.iOS,
        playStoreUrl: 'https://play.google.com/store/apps/details?id=x',
        appStoreUrl: 'https://apps.apple.com/co/app/motoya/id1',
      );

      expect(d!.url, startsWith('https://apps.apple.com/'));
      expect(d.icono, Icons.apple);
    });

    test('sin enlace de su plataforma no hay boton', () {
      // Publicada en Play pero no en la App Store: en iPhone no se ofrece nada.
      // Un boton que no lleva a ninguna parte es peor que no tener boton.
      final d = destinoActualizacion(
        plataforma: TargetPlatform.iOS,
        playStoreUrl: 'https://play.google.com/store/apps/details?id=x',
      );

      expect(d, isNull);
    });

    test('los enlaces en blanco no cuentan como enlace', () {
      final d = destinoActualizacion(
        plataforma: TargetPlatform.android,
        playStoreUrl: '   ',
      );

      expect(d, isNull);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_conductor/ui/core/widgets/banner_version.dart';

void main() {
  group('destinoActualizacion', () {
    test('en Android prefiere Google Play sobre el APK', () {
      final d = destinoActualizacion(
        plataforma: TargetPlatform.android,
        playStoreUrl: 'https://play.google.com/store/apps/details?id=x',
        archivoUrl: 'https://r2/app.apk',
      );

      expect(d!.url, startsWith('https://play.google.com/'));
      expect(d.icono, Icons.shop);
    });

    test('en Android sin Play cae al APK', () {
      final d = destinoActualizacion(
        plataforma: TargetPlatform.android,
        archivoUrl: 'https://r2/app.apk',
      );

      expect(d!.url, 'https://r2/app.apk');
      expect(d.etiqueta, 'Descargar ahora');
    });

    test('en iOS usa el App Store', () {
      final d = destinoActualizacion(
        plataforma: TargetPlatform.iOS,
        appStoreUrl: 'https://apps.apple.com/co/app/motoya/id1',
      );

      expect(d!.icono, Icons.apple);
    });

    test('en iOS nunca ofrece el APK', () {
      final d = destinoActualizacion(
        plataforma: TargetPlatform.iOS,
        playStoreUrl: 'https://play.google.com/x',
        archivoUrl: 'https://r2/app.apk',
      );

      // Un .apk no se instala en un iPhone: mejor sin boton que con un boton
      // que lleva a una descarga inservible.
      expect(d, isNull);
    });

    test('los enlaces en blanco no cuentan como enlace', () {
      final d = destinoActualizacion(
        plataforma: TargetPlatform.android,
        playStoreUrl: '   ',
        archivoUrl: '',
      );

      expect(d, isNull);
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El aviso de "cuenta en revisión" tiene que llevar a alguna parte.
///
/// Decía "estamos revisando tus documentos" incluso cuando no había ninguno que
/// revisar, y para corregirlo había que salir a Perfil y bajar hasta la fila
/// correcta. Un aviso que nombra un problema y no da la salida es la forma de
/// que la cuenta se quede en revisión para siempre.
void main() {
  final inicio =
      File('lib/ui/features/inicio/inicio_screen.dart').readAsStringSync();
  final banner = inicio.substring(
    inicio.indexOf('class _RevisionBanner'),
    inicio.indexOf('class _Ganancias'),
  );

  group('Aviso de cuenta en revisión', () {
    test('nombra los documentos que faltan', () {
      expect(banner, contains('documentosFaltantes'));
      expect(banner, contains(r'Nos falta tu ${faltantes.first}'));
      expect(banner, contains(r'${faltantes.join('));
    });

    test('lleva a la pantalla de documentos', () {
      expect(banner, contains('context.push(Rutas.documentos)'));
    });

    test('con los cuatro subidos no ofrece el botón', () {
      // No hay nada que corregir: un botón ahí es una visita en vano.
      expect(banner, contains('faltantes.isNotEmpty'));
      expect(banner, contains('if (puedeCorregir)'));
    });

    test('rechazado siempre ofrece corregir', () {
      // Aunque estén los cuatro: que te rechacen significa que hay algo que
      // reemplazar.
      expect(banner, contains('rechazado || faltantes.isNotEmpty'));
    });

    test('el motivo del rechazo se muestra tal cual si viene', () {
      expect(banner, contains('vm.motivoRechazo'));
      expect(banner, contains('motivo.isNotEmpty'));
    });
  });
}

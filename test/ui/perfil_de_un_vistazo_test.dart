import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El perfil del conductor tiene que responder de un vistazo la pregunta con la
/// que se entra a él: ¿estoy habilitado y cuánto debo?
///
/// Los cuatro documentos eran la mitad de su altura, así que se fueron a su
/// propia pantalla. Estas dos pantallas necesitan el service locator entero para
/// montarse, así que se vigilan sobre el código las decisiones que se romperían
/// sin ruido —volver a meter los documentos en el perfil no daría ningún error—.
void main() {
  final perfil =
      File('lib/ui/features/perfil/perfil_screen.dart').readAsStringSync();
  final documentos =
      File('lib/ui/features/perfil/documentos_screen.dart').readAsStringSync();
  final router = File('lib/ui/router.dart').readAsStringSync();

  group('Perfil del conductor', () {
    test('abre con el estado de la cuenta y la deuda', () {
      expect(perfil, contains('_CabeceraEstado(conductor: conductor)'));

      final cabecera = perfil.substring(perfil.indexOf('class _CabeceraEstado'));
      // Los cuatro estados, cada uno con su color: no basta con "no habilitado".
      expect(cabecera, contains("'Cuenta rechazada'"));
      expect(cabecera, contains("'Bloqueado por deuda'"));
      expect(cabecera, contains("'En revisión'"));
      expect(cabecera, contains("'Habilitado'"));
      // Color y texto: hay quien mira el celular al sol.
      expect(cabecera, contains('AppColors.success'));
      expect(cabecera, contains('AppColors.danger'));
      expect(cabecera, contains('Formato.moneda(conductor.deudaActual)'));
    });

    test('los documentos ya no se pintan en el perfil', () {
      expect(perfil, isNot(contains('class _Documentos')));
      expect(perfil, isNot(contains('class _FilaDocumento')));
      // Ni la subida: la pantalla de documentos es la única que la tiene.
      expect(perfil, isNot(contains('vm.subirDocumento')));
    });

    test('la fila del perfil resume qué falta y lleva a la subpantalla', () {
      expect(perfil, contains('context.push(Rutas.documentos)'));
      final resumen = perfil.substring(
        perfil.indexOf('String _resumenDocumentos('),
        perfil.indexOf('Future<void> _confirmarSalir('),
      );
      expect(resumen, contains("'Los 4 verificados'"));
      expect(resumen, contains("'Falta \${faltantes.first}'"));
    });

    test('al volver de documentos el perfil recarga', () {
      // La subpantalla tiene su propio view model; sin recargar, el perfil
      // seguiría diciendo que falta algo que se acaba de subir.
      expect(perfil, contains('if (context.mounted) await vm.cargar()'));
    });
  });

  group('Pantalla de documentos', () {
    test('lista los cuatro y conserva la subida', () {
      expect(documentos, contains('DocumentoConductor.values.length'));
      expect(documentos, contains('vm.subirDocumento(doc, source)'));
      expect(documentos, contains('ImageSource.camera'));
      expect(documentos, contains('ImageSource.gallery'));
    });

    test('con los documentos en firme no ofrece reemplazarlos', () {
      // Un botón que siempre responde 409 es peor que no tenerlo.
      expect(documentos, contains('conductor.documentosEnFirme'));
      expect(documentos, contains('devuelva tu cuenta a revisión'));
      expect(documentos, contains('else if (!enFirme)'));
    });

    test('va a pantalla completa sobre el shell', () {
      final ruta = router.substring(router.indexOf('path: Rutas.documentos'));
      expect(ruta.substring(0, 200), contains('parentNavigatorKey: rootKey'));
      expect(router, contains("documentos = '/perfil/documentos'"));
    });
  });
}

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
    test('abre con el estado de la cuenta y el saldo', () {
      expect(perfil, contains('_CabeceraEstado('));
      expect(perfil, contains('conductor: conductor'));

      final cabecera = perfil.substring(perfil.indexOf('class _CabeceraEstado'));
      // Los cuatro estados, cada uno con su color: no basta con "no habilitado".
      expect(cabecera, contains("'Cuenta rechazada'"));
      expect(cabecera, contains("'Bloqueado por deuda'"));
      expect(cabecera, contains("'En revisión'"));
      expect(cabecera, contains("'Habilitado'"));
      // Color y texto: hay quien mira el celular al sol.
      expect(cabecera, contains('AppColors.success'));
      expect(cabecera, contains('AppColors.danger'));
    });

    test('el saldo lleva a la Billetera', () {
      // Es lo que el conductor quiere hacer justo después de leer lo que debe.
      expect(perfil, contains('onVerSaldo: () => _irABilletera(context)'));
      expect(perfil, contains('context.go(Rutas.billetera)'));
      // `go` cambia la rama del shell; `TabActiva` avisa al view model de ese tab
      // de que volvió a ser visible (el shell los conserva en un IndexedStack).
      expect(perfil, contains('TabActiva.billetera'));
    });

    test('el nombre se presenta como dato, no como campo vacío', () {
      // Un `TextField` con `enabled: false` pinta el valor gris sobre un borde
      // apagado: a simple vista es un campo vacío que no se puede llenar.
      expect(perfil, isNot(contains('class _Campo')));
      expect(perfil, isNot(contains('enabled: editable')));
      expect(perfil, contains('_FilaEnFirme('));
      expect(perfil, contains('Icons.lock_outline_rounded'));
      // Y la explicación va junto al dato, no al final del bloque.
      final fila = perfil.substring(perfil.indexOf('class _FilaEnFirme'));
      expect(fila, contains('final String? nota'));
    });

    test('las credenciales no se cortan a mitad de palabra', () {
      // El correo competía por el ancho con dos TextButton en la misma fila y se
      // partía en tres renglones.
      //
      // La fila vivía dentro de esta pantalla y ahora es el componente
      // compartido `core/widgets/credencial_tile.dart`: la regla no cambia, lo
      // que cambia es dónde está escrita. Sale de aquí porque **la disposición
      // es lo que se rompió** y dentro de la pantalla no había forma de montarla
      // en un test; `credencial_tile_test.dart` la monta a 320 dp y con la
      // escala de texto al 130 %, que es donde se rompía de verdad.
      final tile = File(
        'lib/ui/core/widgets/credencial_tile.dart',
      ).readAsStringSync();
      expect(perfil, contains('CredencialTile('));
      expect(tile, contains('maxLines: 1'));
      expect(tile, contains('overflow: TextOverflow.ellipsis'));
      // Las acciones bajan a su propia fila, debajo del valor.
      expect(
        tile.indexOf('overflow: TextOverflow.ellipsis'),
        lessThan(tile.indexOf("Text(tiene ? 'Cambiar' : 'Agregar')")),
      );
    });

    test('sin calificaciones no se presta un 5,0', () {
      expect(perfil, contains("'Sin calificaciones aún'"));
      expect(perfil, contains('(conductor.calificacion ?? 0) > 0'));
    });

    test('cerrar sesión no está duplicado con el perfil cargado', () {
      // El icono de la barra se puso para el caso en que el perfil no carga y hay
      // que poder salir. Con el perfil cargado, la salida es el botón del pie,
      // que es el alcanzable con el pulgar.
      expect(perfil, contains('if (vm.cargando || vm.usuario == null)'));
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
      // La procedencia de la foto la pregunta la hoja compartida, que es la
      // que ofrece cámara y galería. Aquí eran dos `ListTile` sueltos sobre el
      // gris de Material, repetidos en tres pantallas.
      expect(documentos, contains('elegirFotoSheet('));
      final hoja = File(
        'lib/ui/core/widgets/elegir_foto_sheet.dart',
      ).readAsStringSync();
      expect(hoja, contains('ImageSource.camera'));
      expect(hoja, contains('ImageSource.gallery'));
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

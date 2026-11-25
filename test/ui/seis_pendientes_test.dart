import 'dart:io';

import 'package:app_conductor/config/env.dart';
import 'package:app_conductor/ui/core/widgets/soporte.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las seis cosas que quedaron pendientes de la revisión de usabilidad.
///
/// Son decisiones de texto y de flujo: al romperse no dan error, solo vuelven a
/// confundir. Las pantallas necesitan el service locator para montarse, así que
/// se vigilan sobre el código.
void main() {
  String leer(String ruta) => File(ruta).readAsStringSync();

  group('1 · Pagar comisiones', () {
    final billetera = leer('lib/ui/features/billetera/billetera_screen.dart');

    test('la hoja dice que la plata la envía el conductor, en tres pasos', () {
      expect(billetera, contains('La plata la envías tú desde Nequi o tu banco'));
      expect(billetera, contains("'PASO 1 · ENVÍA LA PLATA A ESTA CUENTA'"));
      expect(billetera, contains("'PASO 2 · ¿CUÁNTO ENVIASTE?'"));
      expect(billetera, contains("'PASO 3 · ¿DESDE DÓNDE LA ENVIASTE?'"));
    });

    test('el botón no se llama "Pagar": no mueve plata', () {
      expect(billetera, contains("'Ya transferí \${Formato.moneda(_montoIngresado)}'"));
      expect(billetera, isNot(contains("'Pagar \${Formato.moneda(_montoIngresado)}")));
      expect(billetera, contains('Tócalo solo después de enviar la plata.'));
    });

    test('el comprobante se pide al terminar, como promete la hoja', () {
      expect(billetera, contains('faltaComprobante: pago != null && !pago.tieneComprobante'));
      expect(billetera, contains("label: 'Adjuntar comprobante'"));
      expect(billetera, contains("'Lo adjunto después'"));
      expect(billetera, contains('await _adjuntarComprobante(context, vm, pago.id)'));
    });

    test('con un pago en revisión, registrar otro no es el botón grande', () {
      expect(billetera, contains("'Registrar otro pago'"));
    });
  });

  group('2 · Soporte', () {
    test('hay un número y se muestra legible', () {
      expect(Env.soporteWhatsapp, matches(RegExp(r'^\d{10,13}$')),
          reason: 'wa.me exige indicativo y número, sin + ni espacios.');
      expect(soporteLegible(), '+57 350 485 9462');
    });

    test('donde la app dice "escríbenos" hay un botón que lo hace', () {
      for (final ruta in [
        'lib/ui/features/perfil/perfil_screen.dart',
        'lib/ui/features/perfil/documentos_screen.dart',
        'lib/ui/features/billetera/billetera_screen.dart',
      ]) {
        final fuente = leer(ruta);
        expect(
          fuente.contains('BotonSoporte(') || fuente.contains('abrirSoporte('),
          isTrue,
          reason: '$ruta menciona soporte sin dar cómo contactarlo.',
        );
        expect(fuente, isNot(contains('Contacta al administrador')));
        expect(fuente, isNot(contains('contáctanos.')));
      }
    });

    test('si WhatsApp no abre, el número queda copiado y a la vista', () {
      final soporte = leer('lib/ui/core/widgets/soporte.dart');
      expect(soporte, contains('Clipboard.setData'));
      expect(soporte, contains('No pudimos abrir WhatsApp'));
    });
  });

  group('3 · Registro de cuenta', () {
    final registro = leer('lib/ui/features/auth/registro_screen.dart');
    final registroVm = leer('lib/ui/features/auth/registro_view_model.dart');
    final otp = leer('lib/ui/features/auth/otp_screen.dart');

    test('si el SMS no sale, la pantalla del código lo dice', () {
      expect(registroVm, contains('codigoEnviado = envio.isSuccess'));
      expect(registro, contains('envioFallo: !vm.codigoEnviado'));
      expect(otp, contains('No pudimos enviar el código al'));
      // Y no hay que esperar 42 segundos para pedirlo otra vez.
      expect(otp, contains('if (_sinCodigo) {\n      _segundos = 0;'));
    });

    test('la flecha del código vuelve al formulario sin borrarlo', () {
      expect(otp,
          contains('context.canPop() ? context.pop() : context.go(Rutas.login)'));
    });

    test('"Crear cuenta" dice qué campo está mal y lleva a él', () {
      expect(registro, contains("Text('Revisa: \$mensaje')"));
      expect(registro, contains('Scrollable.ensureVisible('));
    });
  });

  group('4 · Botones que no respondían con datos lentos', () {
    test('"Enviar código" gira dentro de la hoja y no se puede repetir', () {
      final login = leer('lib/ui/features/auth/login_screen.dart');
      expect(login, contains('if (_enviando) return;'));
      expect(login, contains('loading: _enviando'));
    });

    test('"Verificar" y "Cerrar sesión" avisan de que están trabajando', () {
      final perfil = leer('lib/ui/features/perfil/perfil_screen.dart');
      expect(perfil, contains("_conEspera('Cerrando sesión…', vm.cerrarSesion)"));
      expect(perfil, contains("'Enviando el código…'"));
      expect(perfil, contains('if (_esperando) return null;'));
    });
  });

  test('5 · sin cuenta de destino no se puede registrar el pago', () {
    final billetera = leer('lib/ui/features/billetera/billetera_screen.dart');
    expect(billetera, contains('_datosCompletos && _hayDestino(vm)'));
    expect(billetera, contains('No pudimos cargar la cuenta a la que se paga.'));
    expect(billetera, contains("child: const Text('Reintentar')"));
  });

  group('6 · Textos que confundían', () {
    test('las ganancias dicen que ya van sin la comisión', () {
      expect(leer('lib/ui/features/inicio/inicio_screen.dart'),
          contains('ya descontada la comisión de Zumbeo'));
      expect(leer('lib/ui/features/historial/historial_screen.dart'),
          contains('Ganancias esta semana (ya sin la comisión)'));
    });

    test('"aceptación" y "en línea" se explican', () {
      final inicio = leer('lib/ui/features/inicio/inicio_screen.dart');
      expect(inicio, contains("etiqueta: 'en línea esta vez'"));
      expect(inicio, contains("title: const Text('Pedidos aceptados')"));
      expect(inicio, isNot(contains("etiqueta: 'aceptación'")));
    });

    test('nadie "liquida" ni hay "no comisionable"', () {
      expect(leer('lib/ui/features/onboarding/onboarding_screen.dart'),
          isNot(contains('iquída')));
      expect(leer('lib/ui/features/pedido_detalle/pedido_detalle_screen.dart'),
          isNot(contains('no comisionable')));
    });
  });
}

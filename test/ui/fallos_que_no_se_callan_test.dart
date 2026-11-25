import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fallos que la app se callaba.
///
/// Todos tienen la misma forma: una petición falla (casi siempre por la señal) y
/// la pantalla, en vez de decirlo, pinta el caso vacío. El conductor no ve un
/// error: ve que sus pedidos, sus ganancias o sus documentos "desaparecieron".
/// Montar estas pantallas exige el service locator entero, así que se vigilan
/// sobre el código.
void main() {
  String leer(String ruta) => File(ruta).readAsStringSync();

  test('Historial: si la carga falla se dice, no "Aún no tienes pedidos"', () {
    final pantalla = leer('lib/ui/features/historial/historial_screen.dart');
    final vm = leer('lib/ui/features/historial/historial_view_model.dart');
    expect(pantalla, contains('vm.error != null && vm.grupos.isEmpty'));
    expect(pantalla, contains('ErrorRetry('));
    expect(vm, contains('errorEsRed = f.isNetwork'));
  });

  test('Inicio: un refresco fallido no pone las ganancias del día en cero',
      () {
    final vm = leer('lib/ui/features/inicio/inicio_view_model.dart');
    final metricas = vm.substring(
      vm.indexOf('Future<void> _cargarMetricas()'),
      vm.indexOf('gananciasHoy = suma;'),
    );
    expect(metricas, contains('if (lista == null) return;'));
    expect(metricas, isNot(contains('?? const <Pedido>[]')));
  });

  test('Arranque: sin señal no se manda al alta a quien ya está registrado',
      () {
    final splash = leer('lib/ui/features/splash/splash_screen.dart');
    expect(splash, contains('when f.statusCode != 404'));
    expect(splash, contains('onRetry: _reintentar'));
  });

  test('Oferta: el banner no entrega un reloj viejo', () {
    final pantalla = leer('lib/ui/features/inicio/inicio_screen.dart');
    final vm = leer('lib/ui/features/inicio/inicio_view_model.dart');
    expect(pantalla, contains('segundos: vm.segundosRestantesOferta'));
    expect(pantalla, isNot(contains('segundos: oferta.segundosRestantes')));
    expect(vm, contains('_ofertaVistaEn = DateTime.now();'));
  });

  group('La tarjeta de En línea', () {
    final pantalla = leer('lib/ui/features/inicio/inicio_screen.dart');
    final vm = leer('lib/ui/features/inicio/inicio_view_model.dart');

    test('bloqueada o sin habilitar, lleva a donde se arregla', () {
      expect(pantalla, contains('locator<TabActiva>().cambiar(TabActiva.billetera)'));
      expect(pantalla, contains('() => context.push(Rutas.documentos)'));
    });

    test('rechazada no se anuncia como "en revisión"', () {
      expect(pantalla, contains('No fue aprobada. Toca aquí para corregir'));
    });

    test('responde desde el primer toque y no admite dos a la vez', () {
      expect(vm, contains('if (_alternando) return ResultadoEnLinea.ok;'));
    });

    test('desconectarse con un pedido encima se confirma', () {
      expect(pantalla, contains('} else if (vm.pedidosActivos.isNotEmpty) {'));
      expect(pantalla, contains("'Tienes un pedido en curso'"));
    });
  });

  test('Billetera: un pago que no se confirmó no va en verde', () {
    final pantalla = leer('lib/ui/features/billetera/billetera_screen.dart');
    final vm = leer('lib/ui/features/billetera/billetera_view_model.dart');
    expect(vm, contains('avisoEsError = true;'));
    expect(pantalla, contains('esError: vm.avisoEsError'));
    expect(pantalla, contains('AppColors.dangerSurface, AppColors.danger'));
  });

  test('Documentos: el motivo del rechazo se lee entero donde se corrige', () {
    final docs = leer('lib/ui/features/perfil/documentos_screen.dart');
    expect(docs, contains('if (conductor.rechazado)'));
    expect(docs, contains('conductor.motivoRechazo'));
    expect(docs, contains("'Falta subirla'"));
  });

  test('Las hojas con formulario dejan sitio a la barra del sistema', () {
    for (final ruta in [
      'lib/ui/features/auth/login_screen.dart',
      'lib/ui/features/perfil/perfil_screen.dart',
    ]) {
      final fuente = leer(ruta);
      expect(
        RegExp(r'viewInsets\.bottom \+ AppSpacing\.xl').hasMatch(fuente),
        isFalse,
        reason: '$ruta: una hoja sin `padding.bottom` deja su botón detrás de '
            'los botones de navegación de Android.',
      );
    }
  });
}

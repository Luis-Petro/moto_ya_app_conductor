import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La pantalla de entrega, en la calle y con datos móviles.
///
/// `PedidoActivoScreen` necesita el service locator entero para montarse, así que
/// estas decisiones se vigilan sobre el código — son las que al romperse no dan
/// ningún error y solo se notan con el cliente delante. El comportamiento de red
/// (que una evidencia fallida no marque el pedido entregado, y el progreso) sí se
/// prueba de verdad en `test/data/entregar_con_evidencia_test.dart`.
void main() {
  final pantalla = File(
    'lib/ui/features/pedido_activo/pedido_activo_screen.dart',
  ).readAsStringSync();
  final vm = File(
    'lib/ui/features/pedido_activo/pedido_activo_view_model.dart',
  ).readAsStringSync();

  group('Captura y compresión', () {
    test('la captura baja a 1280 px y calidad 55', () {
      expect(pantalla, contains('imageQuality: 55'));
      expect(pantalla, contains('maxWidth: 1280'));
    });

    test('la foto pasa por el compresor antes de quedar lista', () {
      expect(pantalla, contains('_compresor.aTope(File(foto.path))'));
      // Y se guarda el peso: es lo que permite decir cuánto está esperando.
      expect(pantalla, contains('_pesoEvidencia = peso'));
    });
  });

  group('Progreso de la subida', () {
    test('nunca se inventa un porcentaje', () {
      // Dio manda `total` en -1 cuando no lo conoce. Ahí el indicador tiene que
      // quedar indeterminado, no en un número cualquiera.
      expect(vm, contains('total > 0'));
      expect(vm, contains('progresoSubida = null'));
      // `value` nulo en LinearProgressIndicator = indeterminado.
      expect(pantalla, contains('LinearProgressIndicator(value: progreso)'));
    });

    test('el peso se muestra en unidades legibles', () {
      expect(pantalla, contains(r'} MB'));
      expect(pantalla, contains(r'} KB'));
    });
  });

  group('Un fallo de red no cuesta repetir la foto', () {
    test('el botón pasa a reintentar el envío', () {
      expect(pantalla, contains("_falloConFoto ? 'Reintentar envío'"));
      expect(pantalla, contains('setState(() => _falloConFoto = true)'));
    });

    test('el aviso dice que la foto sigue guardada', () {
      expect(pantalla, contains('La foto sigue '));
      expect(pantalla, contains("'La foto sigue guardada'"));
    });

    test('hay una salida explícita para descartarla y volver a capturar', () {
      expect(pantalla, contains("'Tomar otra foto'"));
      expect(pantalla, contains('void _descartarEvidencia()'));
    });

    test('durante la subida no se abre la cámara', () {
      // Se perdería la foto que se está enviando.
      expect(pantalla, contains('onTap: subiendo ? null : onTap'));
    });
  });

  group('Doble toque', () {
    test('el botón se deshabilita y la acción se protege', () {
      // El botón deshabilitado no basta: entre el toque y el primer rebuild hay
      // una ventana, y dos entregas son dos subidas y dos avances de estado.
      expect(pantalla, contains('vm.proximoEstado == null || vm.procesando'));
      expect(pantalla, contains('if (vm.procesando) return;'));
    });
  });

  test('las coordenadas de la evidencia son las de la captura', () {
    // Comprimir toca los bytes de la imagen, nada más: el punto y la hora los
    // pone el backend con `coordenadas`, que sale de la posición reportada.
    expect(vm, contains('coordenadas: posicion'));
  });
}

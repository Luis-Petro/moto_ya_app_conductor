import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardas del **pedido encadenado en la interfaz**.
///
/// El backend lleva la función completa desde hace meses, apagada tras
/// `MATCHING_ENCADENADO_HABILITADO`. Lo que faltaba estaba entero en la app: el
/// Inicio ocultaba la tarjeta de oferta en cuanto había un pedido en curso, así
/// que al encender la clave el conductor habría recibido ofertas que **nunca
/// habría visto** — se vencían solas y le bajaban la tasa de aceptación por no
/// responder algo que la pantalla no le enseñó.
///
/// Son comprobaciones sobre el código porque el fallo es una condición que
/// desaparece, no un valor que se calcula mal: reaparece con una línea y no da
/// ningún error.
void main() {
  const inicio = 'lib/ui/features/inicio/inicio_screen.dart';
  const viewModel = 'lib/ui/features/inicio/inicio_view_model.dart';

  test('la oferta no se oculta por llevar un pedido en curso', () {
    final src = File(inicio).readAsStringSync();
    expect(
      src,
      isNot(contains('vm.pedidoActivo == null')),
      reason: 'El Inicio vuelve a esconder la oferta cuando hay un pedido en '
          'curso. Eso deja el pedido encadenado sin ninguna vía de llegar al '
          'conductor: la oferta existe, se vence sola y le cuesta aceptación.',
    );
  });

  test('el Inicio pinta una tarjeta por cada pedido en curso', () {
    final src = File(inicio).readAsStringSync();
    // Recorrer la lista es lo que distingue "puede llevar dos" de "lleva uno y
    // el otro está en algún sitio". Sin esto el segundo pedido solo se alcanza
    // rebuscando en el historial.
    expect(src, contains('for (final p in vm.pedidosActivos)'));
  });

  test('el estado del Inicio es una lista, no un pedido suelto', () {
    final src = File(viewModel).readAsStringSync();
    expect(src, contains('List<Pedido> pedidosActivos'));
    // El singular sigue existiendo como atajo al primero (el que tomó antes),
    // pero derivado de la lista: dos fuentes de verdad para lo mismo es como se
    // acaba pintando un pedido que ya se entregó.
    expect(src, contains('Pedido? get pedidoActivo'));
  });

  test('un fallo de red no borra los pedidos en curso de la pantalla', () {
    final src = File('lib/data/repositories/pedido_repository.dart')
        .readAsStringSync();
    // `null` = no se pudo consultar; `[]` = no tiene ninguno. Confundirlos hace
    // que un tick perdido borre de la pantalla un pedido que el conductor está
    // haciendo en ese momento.
    expect(src, contains('Future<List<Pedido>?> pedidosActivos()'));
    expect(src, contains('err: (_) => null'));
  });

  test('la posición se retransmite a todos los pedidos en curso', () {
    final src = File(viewModel).readAsStringSync();
    // Con dos pedidos encima, el cliente del que no está en pantalla vería el
    // marcador congelado y un ETA que no avanza.
    expect(src, contains('for (final p in pedidosActivos)'));
    expect(src, contains('reportarPosicion'));
  });
}

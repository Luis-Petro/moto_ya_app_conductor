import 'package:app_conductor/domain/models/categoria_servicio.dart';
import 'package:app_conductor/domain/models/estado_pedido.dart';
import 'package:app_conductor/domain/models/historial_del_cliente.dart';
import 'package:app_conductor/domain/models/pedido.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// El rótulo con el que el conductor decide antes de poner su propia plata.
///
/// Es un **agregado y nada más**: dice cuántos pedidos con compra ha completado
/// ese cliente, y ni el tope de esa persona ni ninguna marca de impago llegan
/// nunca a esta app. Una marca de un solo conductor, sin revisar, no puede
/// convertirse en la etiqueta que el municipio le cuelga a alguien.
void main() {
  Pedido pedido({required bool requiereCompra, int? completados}) => Pedido(
        id: 1,
        clienteId: 5,
        categoria: CategoriaServicio.mercado,
        descripcion: 'Mercado de la semana',
        origen: const LatLng(9.35, -75.95),
        destino: const LatLng(9.36, -75.96),
        estado: EstadoPedido.buscandoConductor,
        requiereCompra: requiereCompra,
        montoCompraEstimado: requiereCompra ? 28000 : null,
        pedidosConAdelantoDelCliente: completados,
      );

  test('sin compra adelantada no dice nada', () {
    expect(historialDelCliente(pedido(requiereCompra: false, completados: 14)),
        isNull,
        reason: 'sin plata que arriesgar es un dato sobre una persona que no '
            'hace falta para decidir');
  });

  test('con compra y sin el dato tampoco', () {
    // Un backend anterior, o un dato que no se pudo resolver. La tarjeta se
    // queda exactamente como estaba antes de que este rótulo existiera.
    expect(historialDelCliente(pedido(requiereCompra: true)), isNull);
  });

  test('cliente nuevo se dice sin cifra que interpretar', () {
    final rotulo =
        historialDelCliente(pedido(requiereCompra: true, completados: 0));

    expect(rotulo, isNotNull);
    expect(rotulo, contains('nuevo'));
    expect(rotulo, isNot(contains('0 pedidos')),
        reason: '"0 pedidos" se lee como un dato averiado');
  });

  test('con historial dice cuántos', () {
    expect(historialDelCliente(pedido(requiereCompra: true, completados: 14)),
        contains('14'));
  });

  test('uno solo va en singular', () {
    final rotulo =
        historialDelCliente(pedido(requiereCompra: true, completados: 1));

    expect(rotulo, contains('1 pedido con compra'));
    expect(rotulo, isNot(contains('pedidos')));
  });

  test('nunca nombra el tope ni un impago', () {
    for (final completados in [0, 1, 14]) {
      final rotulo = historialDelCliente(
          pedido(requiereCompra: true, completados: completados))!;
      expect(rotulo.toLowerCase(), isNot(contains('tope')));
      expect(rotulo.toLowerCase(), isNot(contains('impago')));
      expect(rotulo.toLowerCase(), isNot(contains('reembols')));
    }
  });
}

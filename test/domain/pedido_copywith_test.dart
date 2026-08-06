import 'package:app_conductor/domain/models/categoria_servicio.dart';
import 'package:app_conductor/domain/models/estado_pedido.dart';
import 'package:app_conductor/domain/models/pedido.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// El pedido activo se reconstruye en cada avance de estado y en cada evento
/// STOMP. Cuando se reconstruía campo por campo, el contacto del cliente y la
/// referencia de recogida desaparecían a mitad del pedido.
void main() {
  final pedido = Pedido(
    id: 7,
    clienteId: 100,
    conductorId: 20,
    categoria: CategoriaServicio.mercado,
    descripcion: 'Mercado de la semana',
    origen: const LatLng(9.35, -75.95),
    destino: const LatLng(9.36, -75.96),
    direccionRecogida: 'Calle 1',
    direccionDestino: 'Calle 2',
    referenciaRecogida: 'Al lado de la panadería',
    referencia: 'Portón azul',
    fotoUrl: 'https://cdn/pedido.jpg',
    tarifaSugerida: 9000,
    tarifaFinal: 10000,
    recargoAdelanto: 1500,
    recargoEspera: 500,
    requiereCompra: true,
    montoCompraEstimado: 150000,
    requiereEspera: true,
    minutosEsperaEstimados: 10,
    estado: EstadoPedido.aceptado,
    clienteNombre: 'Marta Gómez',
    clienteTelefono: '+573001112233',
    clienteFotoUrl: 'https://cdn/marta.jpg',
    distanciaEstimadaMetros: 2500,
    duracionEstimadaSegundos: 420,
    rutaPolyline: 'abc123',
  );

  test('copyWith cambia el estado y conserva todo lo demás', () {
    final avanzado = pedido.copyWith(estado: EstadoPedido.enCamino);

    expect(avanzado.estado, EstadoPedido.enCamino);
    expect(avanzado.clienteNombre, 'Marta Gómez');
    expect(avanzado.clienteTelefono, '+573001112233');
    expect(avanzado.clienteFotoUrl, 'https://cdn/marta.jpg');
    expect(avanzado.referenciaRecogida, 'Al lado de la panadería');
    expect(avanzado.referencia, 'Portón azul');
    expect(avanzado.fotoUrl, 'https://cdn/pedido.jpg');
    expect(avanzado.origen, pedido.origen);
    expect(avanzado.destino, pedido.destino);
    expect(avanzado.direccionRecogida, 'Calle 1');
    expect(avanzado.direccionDestino, 'Calle 2');
    expect(avanzado.tarifaSugerida, 9000);
    expect(avanzado.tarifaFinal, 10000);
    expect(avanzado.recargoAdelanto, 1500);
    expect(avanzado.recargoEspera, 500);
    expect(avanzado.requiereCompra, isTrue);
    expect(avanzado.montoCompraEstimado, 150000);
    expect(avanzado.requiereEspera, isTrue);
    expect(avanzado.minutosEsperaEstimados, 10);
    expect(avanzado.rutaPolyline, 'abc123');
    expect(avanzado.distanciaEstimadaMetros, 2500);
    expect(avanzado.duracionEstimadaSegundos, 420);
  });
}

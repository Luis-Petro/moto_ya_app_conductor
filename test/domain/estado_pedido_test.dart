import 'package:app_conductor/domain/models/estado_pedido.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EstadoPedido', () {
    test('fromWire mapea los valores del backend', () {
      expect(EstadoPedido.fromWire('EN_CAMINO'), EstadoPedido.enCamino);
      expect(EstadoPedido.fromWire('ENTREGADO'), EstadoPedido.entregado);
      expect(EstadoPedido.fromWire(null), EstadoPedido.pendiente);
      expect(EstadoPedido.fromWire('DESCONOCIDO'), EstadoPedido.pendiente);
    });

    test('esFinal y estaActivo', () {
      expect(EstadoPedido.entregado.esFinal, isTrue);
      expect(EstadoPedido.cancelado.esFinal, isTrue);
      expect(EstadoPedido.enCamino.esFinal, isFalse);
      expect(EstadoPedido.enCamino.estaActivo, isTrue);
      expect(EstadoPedido.entregado.estaActivo, isFalse);
    });

    test('indiceTracking refleja el progreso', () {
      expect(EstadoPedido.buscandoConductor.indiceTracking, 0);
      expect(EstadoPedido.aceptado.indiceTracking, 1);
      expect(EstadoPedido.enCompra.indiceTracking, 2);
      expect(EstadoPedido.enCamino.indiceTracking, 3);
      expect(EstadoPedido.entregado.indiceTracking, 4);
      expect(EstadoPedido.cancelado.indiceTracking, -1);
    });
  });
}


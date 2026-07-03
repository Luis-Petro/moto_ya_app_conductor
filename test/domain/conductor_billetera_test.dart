import 'package:app_conductor/data/models/api_mappers.dart';
import 'package:app_conductor/domain/models/billetera.dart';
import 'package:app_conductor/domain/models/conductor.dart';
import 'package:app_conductor/domain/models/pedido.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pedido — desglose económico', () {
    test('comisión es 15% y ganancia neta 85% del servicio', () {
      expect(Pedido.comision(10000), 1500);
      expect(Pedido.gananciaNeta(10000), 8500);
      expect(Pedido.gananciaNeta(12000), closeTo(10200, 0.001));
    });
  });

  group('Conductor', () {
    test('perfilCompleto requiere vehículo y placa (licencia opcional)', () {
      const incompleto = Conductor(id: 1, usuarioId: 2, licencia: 'X');
      expect(incompleto.perfilCompleto, isFalse);
      const sinLicencia =
          Conductor(id: 1, usuarioId: 2, vehiculo: 'Moto', placa: 'ABC12D');
      expect(sinLicencia.perfilCompleto, isTrue);
      const completo = Conductor(
          id: 1, usuarioId: 2, licencia: 'X', vehiculo: 'Moto', placa: 'ABC12D');
      expect(completo.perfilCompleto, isTrue);
    });

    test('bloqueadoPorDeuda refleja el estado', () {
      const c = Conductor(
          id: 1, usuarioId: 2, estado: EstadoConductor.bloqueadoPorDeuda);
      expect(c.bloqueadoPorDeuda, isTrue);
    });
  });

  group('Billetera', () {
    test('porcentaje de uso y disponible', () {
      const b = Billetera(deudaActual: 3600, limite: 50000);
      expect(b.porcentajeUso, 7);
      expect(b.disponible, 46400);
      expect(b.bloqueado, isFalse);
    });

    test('bloqueado cuando el estado lo indica y supera el límite', () {
      const b = Billetera(
          deudaActual: 51200,
          limite: 50000,
          estado: EstadoConductor.bloqueadoPorDeuda);
      expect(b.bloqueado, isTrue);
      expect(b.porcentajeUso, 102);
      expect(b.disponible, 0);
    });
  });

  group('ApiMappers.conductor / billetera', () {
    test('mapea el perfil del conductor', () {
      final c = ApiMappers.conductor({
        'id': 3,
        'usuarioId': 7,
        'licencia': 'LIC1',
        'vehiculo': 'Moto Yamaha',
        'placa': 'ABC12D',
        'enLinea': true,
        'deudaActual': 3600,
        'calificacion': 4.9,
        'estado': 'ACTIVO',
      });
      expect(c.perfilCompleto, isTrue);
      expect(c.enLinea, isTrue);
      expect(c.deudaActual, 3600);
      expect(c.calificacion, 4.9);
      expect(c.estado, EstadoConductor.activo);
    });

    test('mapea la billetera con límite alternativo', () {
      final b = ApiMappers.billetera(
          {'deudaActual': 51200, 'limiteDeuda': 50000, 'estado': 'BLOQUEADO_POR_DEUDA'});
      expect(b.deudaActual, 51200);
      expect(b.limite, 50000);
      expect(b.bloqueado, isTrue);
    });
  });
}

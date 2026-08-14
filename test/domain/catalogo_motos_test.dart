import 'package:app_conductor/domain/models/catalogo_motos.dart';
import 'package:flutter_test/flutter_test.dart';

/// El catálogo de motos y cómo se compone el `vehiculo` que va al backend.
///
/// Lo que se fija aquí es sobre todo el **contrato**: por muchas listas que se
/// añadan de este lado, lo que viaja sigue siendo un solo texto en el mismo
/// campo de siempre. Partirlo en dos columnas obligaría a migrar los registros
/// existentes y a decidir qué hacer con los que no encajen, todo para un dato
/// que hoy solo se lee.
void main() {
  group('catalogoMotos', () {
    test('las marcas populares de la zona van primero', () {
      // No es orden alfabético a propósito: bajar hasta la V para encontrar una
      // Victory es el mismo trabajo que este desplegable venía a quitar.
      expect(marcasMoto.take(3), ['Bajaj', 'TVS', 'Victory']);
    });

    test('"Otra…" cierra la lista de marcas', () {
      expect(marcasMoto.last, kOtro);
    });

    test('la Boxer es un modelo de Bajaj, no una marca', () {
      expect(marcasMoto, isNot(contains('Boxer')));
      expect(catalogoMotos['Bajaj']!.first, startsWith('Boxer'));
    });

    test('sin marca no hay modelos que ofrecer', () {
      // Un desplegable que se abre y no muestra nada parece la app rota.
      expect(modelosDe(null), isEmpty);
    });

    test('con "Otra" en la marca tampoco hay lista de modelos', () {
      expect(modelosDe(kOtro), isEmpty);
    });

    test('los modelos de una marca terminan en "Otra…"', () {
      final modelos = modelosDe('Yamaha');

      expect(modelos, contains('FZ 150'));
      expect(modelos.last, kOtro);
    });
  });

  group('componerVehiculo', () {
    test('une marca y modelo', () {
      expect(componerVehiculo('Bajaj', 'Boxer CT 100'), 'Bajaj Boxer CT 100');
    });

    test('no repite la marca si el modelo ya la trae', () {
      // Pasa con el campo libre: alguien escribe "Bajaj Boxer" en modelo y el
      // cliente acabaría viendo "Bajaj Bajaj Boxer".
      expect(componerVehiculo('Bajaj', 'Bajaj Boxer'), 'Bajaj Boxer');
    });

    test('ignora los espacios sobrantes', () {
      expect(componerVehiculo('  TVS ', ' Sport 100 '), 'TVS Sport 100');
    });

    test('sin modelo no hay vehículo', () {
      // Media moto es un dato que no dice nada, y el alta ya exige el campo.
      expect(componerVehiculo('Bajaj', null), isNull);
      expect(componerVehiculo('Bajaj', '  '), isNull);
    });

    test('sin marca no hay vehículo', () {
      expect(componerVehiculo(null, 'Boxer CT 100'), isNull);
    });
  });
}

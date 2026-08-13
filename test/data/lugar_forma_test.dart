import 'package:app_conductor/data/models/api_mappers.dart';
import 'package:app_conductor/ui/core/widgets/lugar_marcadores.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mapeo de la forma (Ã¡rea) de un lugar y su conversiÃ³n a polÃ­gonos.
///
/// El eje de todo esto: **una forma malformada es un lugar sin forma, nunca una
/// excepciÃ³n**. `GET /lugares/mapa` trae el municipio entero; un trazo corrupto
/// en una fila no puede dejar la pantalla sin mapa.
void main() {
  Map<String, dynamic> lugarJson(dynamic forma) => {
        'id': 3,
        'nombre': 'Parque Principal',
        'categoria': 'REFERENCIA',
        'lat': 9.3532,
        'lng': -75.9536,
        if (forma != null) 'forma': forma,
      };

  group('ApiMappers.lugar â€” forma', () {
    test('mapea los vÃ©rtices en orden lat, lng', () {
      final l = ApiMappers.lugar(lugarJson([
        [9.3535, -75.9539],
        [9.3535, -75.9533],
        [9.3529, -75.9533],
        [9.3529, -75.9539],
      ]));

      expect(l.tieneForma, isTrue);
      expect(l.forma, hasLength(4));
      // Primero latitud. El orden inverso de GeoJSON pondrÃ­a el parque en Somalia.
      expect(l.forma!.first.latitude, 9.3535);
      expect(l.forma!.first.longitude, -75.9539);
    });

    test('el punto se conserva tal cual: no se deriva de la forma', () {
      final l = ApiMappers.lugar(lugarJson([
        [9.3535, -75.9539],
        [9.3535, -75.9533],
        [9.3529, -75.9536],
      ]));

      expect(l.punto.latitude, 9.3532);
      expect(l.punto.longitude, -75.9536);
    });

    test('sin forma el lugar es un punto', () {
      final l = ApiMappers.lugar(lugarJson(null));

      expect(l.forma, isNull);
      expect(l.tieneForma, isFalse);
    });

    test('una forma que no sirve se ignora, no revienta', () {
      final invalidas = [
        <dynamic>[], // vacÃ­a
        [
          [9.35, -75.95],
          [9.36, -75.96],
        ], // dos vÃ©rtices: una lÃ­nea
        [
          [9.35, -75.95],
          [9.36],
          [9.37, -75.97],
        ], // par incompleto
        [
          [9.35, -75.95],
          'no es un par',
          [9.37, -75.97],
        ],
        'ni siquiera es una lista',
      ];

      for (final forma in invalidas) {
        final l = ApiMappers.lugar(lugarJson(forma));
        expect(l.forma, isNull, reason: 'forma invÃ¡lida: $forma');
        expect(l.nombre, 'Parque Principal');
      }
    });
  });

  group('poligonosDeLugares', () {
    test('solo dibuja los lugares que son un Ã¡rea', () {
      final parque = ApiMappers.lugar(lugarJson([
        [9.3535, -75.9539],
        [9.3535, -75.9533],
        [9.3529, -75.9536],
      ]));
      final tienda = ApiMappers.lugar(lugarJson(null));

      final poligonos = poligonosDeLugares([parque, tienda, parque]);

      expect(poligonos, hasLength(2));
      expect(poligonos.first.points, hasLength(3));
    });

    test('el relleno es translÃºcido: no puede tapar la ruta del pedido', () {
      final parque = ApiMappers.lugar(lugarJson([
        [9.3535, -75.9539],
        [9.3535, -75.9533],
        [9.3529, -75.9536],
      ]));

      final poligono = poligonosDeLugares([parque]).single;

      expect(poligono.color!.a, lessThan(0.3));
      expect(poligono.borderStrokeWidth, 1.5);
    });

    test('sin Ã¡reas no hay polÃ­gonos que dibujar', () {
      expect(poligonosDeLugares([ApiMappers.lugar(lugarJson(null))]), isEmpty);
    });
  });
}


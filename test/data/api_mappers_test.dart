import 'package:app_conductor/data/models/api_mappers.dart';
import 'package:app_conductor/domain/models/categoria_servicio.dart';
import 'package:app_conductor/domain/models/estado_pedido.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiMappers.pedido', () {
    test('mapea los campos principales del JSON del backend', () {
      final json = {
        'id': 1042,
        'clienteId': 7,
        'conductorId': 3,
        'categoria': 'COMIDA',
        'descripcion': 'Pizza familiar',
        'direccionDestino': 'Cra 8 #4-21',
        'referencia': 'Casa blanca',
        'origenLat': 6.0289,
        'origenLng': -75.4309,
        'destinoLat': 6.0301,
        'destinoLng': -75.4290,
        'tarifaSugerida': 10000,
        'tarifaFinal': 12000,
        'estado': 'EN_CAMINO',
        'creadoEn': '2026-06-27T15:03:20Z',
      };

      final p = ApiMappers.pedido(json);

      expect(p.id, 1042);
      expect(p.conductorId, 3);
      expect(p.categoria, CategoriaServicio.comida);
      expect(p.estado, EstadoPedido.enCamino);
      expect(p.tarifaSugerida, 10000);
      expect(p.tarifaFinal, 12000);
      expect(p.creadoEn, isNotNull);
      // Coordenadas planas â†’ LatLng
      expect(p.origen?.latitude, 6.0289);
      expect(p.origen?.longitude, -75.4309);
      expect(p.destino?.latitude, 6.0301);
    });

    test('tolera campos opcionales ausentes', () {
      final p = ApiMappers.pedido({
        'id': 1,
        'categoria': 'MANDADO',
        'descripcion': 'x',
        'estado': 'PENDIENTE',
      });
      expect(p.conductorId, isNull);
      expect(p.tarifaSugerida, isNull);
      expect(p.origen, isNull);
    });
  });

  test('ApiMappers.sesion mapea token y rol', () {
    final s = ApiMappers.sesion({'token': 't', 'usuarioId': 9, 'rol': 'CLIENTE'});
    expect(s.token, 't');
    expect(s.usuarioId, 9);
  });
}


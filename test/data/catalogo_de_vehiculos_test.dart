import 'package:app_conductor/data/models/api_mappers.dart';
import 'package:app_conductor/data/services/api_client.dart';
import 'package:app_conductor/data/services/api_result.dart';
import 'package:app_conductor/data/services/vehiculo_service.dart';
import 'package:app_conductor/domain/models/catalogo_vehiculos.dart';
import 'package:flutter_test/flutter_test.dart';

/// El catálogo de vehículos que administra el panel.
///
/// Lo que aquí se fija es lo que hace que este catálogo pueda crecer sin
/// publicar una versión de la app: que el **orden del servidor se conserve**, que
/// una clave de silueta desconocida no rompa nada, y que un catálogo vacío se
/// trate como lo que es —una lista vacía— y no como un error.
void main() {
  Map<String, dynamic> modelo(int id, String nombre, {String? imagen}) => {
        'id': id,
        'nombre': nombre,
        'imagenUrl': imagen,
      };

  Map<String, dynamic> marca(int id, String nombre,
          {List<Map<String, dynamic>> modelos = const []}) =>
      {'id': id, 'nombre': nombre, 'imagenUrl': null, 'modelos': modelos};

  Map<String, dynamic> tipo(int id, String nombre, String icono,
          {List<Map<String, dynamic>> marcas = const []}) =>
      {
        'id': id,
        'nombre': nombre,
        'icono': icono,
        'imagenUrl': null,
        'marcas': marcas,
      };

  group('el árbol', () {
    test('cada nivel cuelga del anterior', () {
      final c = ApiMappers.catalogoVehiculos({
        'tipos': [
          tipo(1, 'Moto', 'MOTO', marcas: [
            marca(10, 'Bajaj', modelos: [modelo(100, 'Boxer CT 100')]),
          ]),
          tipo(2, 'Bicicleta', 'BICICLETA', marcas: [marca(11, 'GW')]),
        ],
      });

      expect(c.tipos.map((t) => t.nombre), ['Moto', 'Bicicleta']);
      expect(c.tipos[0].marcas.single.nombre, 'Bajaj');
      expect(c.tipos[0].marcas.single.modelos.single.nombre, 'Boxer CT 100');
      expect(c.tipos[1].marcas.single.modelos, isEmpty);
    });

    test('el orden es el del servidor, no el alfabético', () {
      // El catálogo se ordena por uso real en el municipio: alfabéticamente, la
      // marca que conduce la mitad de la flota queda por detrás de las que casi
      // nadie tiene.
      final c = ApiMappers.catalogoVehiculos({
        'tipos': [
          tipo(1, 'Moto', 'MOTO',
              marcas: [marca(11, 'Victory'), marca(10, 'Bajaj')]),
        ],
      });

      expect(c.tipos.single.marcas.map((m) => m.nombre), ['Victory', 'Bajaj']);
    });
  });

  group('la silueta de respaldo', () {
    test('cada clave conocida tiene la suya', () {
      expect(IconoVehiculo.desde('MOTO'), IconoVehiculo.moto);
      expect(IconoVehiculo.desde('BICICLETA'), IconoVehiculo.bicicleta);
      expect(IconoVehiculo.desde('TRICIMOTO'), IconoVehiculo.tricimoto);
      expect(IconoVehiculo.desde('CARRO'), IconoVehiculo.carro);
      expect(IconoVehiculo.desde('A_PIE'), IconoVehiculo.aPie);
    });

    test('una clave que esta app no conoce cae en la genérica, sin lanzar', () {
      // Es lo que permite que el panel cree un tipo nuevo y se ofrezca desde el
      // primer minuto, sin publicar una versión de la app.
      expect(IconoVehiculo.desde('HELICOPTERO'), IconoVehiculo.otro);
      expect(IconoVehiculo.desde(null), IconoVehiculo.otro);
    });

    test('un tipo con icono desconocido se ofrece igual', () {
      final c = ApiMappers.catalogoVehiculos({
        'tipos': [tipo(9, 'Patineta', 'PATINETA')],
      });

      expect(c.tipos.single.nombre, 'Patineta');
      expect(c.tipos.single.icono, IconoVehiculo.otro);
    });
  });

  group('tolerancia', () {
    test('una fila sin nombre se descarta y las demás siguen', () {
      // Perder el catálogo entero por una fila rara sería dejar sin registrarse
      // a quien no tiene nada que ver con ella.
      final c = ApiMappers.catalogoVehiculos({
        'tipos': [
          tipo(1, 'Moto', 'MOTO', marcas: [
            {'id': 10, 'nombre': '  ', 'modelos': []},
            marca(11, 'Bajaj'),
          ]),
        ],
      });

      expect(c.tipos.single.marcas.map((m) => m.nombre), ['Bajaj']);
    });

    test('un catálogo vacío es una lista vacía, no un error', () {
      final c = ApiMappers.catalogoVehiculos({'tipos': <dynamic>[]});

      expect(c.estaVacio, isTrue);
      expect(c.tipos, isEmpty);
    });

    test('sin la clave tipos tampoco lanza', () {
      expect(ApiMappers.catalogoVehiculos(<String, dynamic>{}).estaVacio, isTrue);
    });
  });

  group('el servicio', () {
    test('pide el árbol en UNA sola petición', () async {
      // Tres viajes en el paso del vehículo son tres oportunidades de fallar en
      // el sitio donde una persona está intentando empezar a trabajar.
      final api = _ApiFake({
        'tipos': [
          tipo(1, 'Moto', 'MOTO', marcas: [
            marca(10, 'Bajaj', modelos: [modelo(100, 'Boxer CT 100')]),
          ]),
        ],
      });

      final res = await VehiculoService(api).catalogo();

      expect(api.llamadas, 1);
      expect(api.rutas, ['/vehiculos/catalogo']);
      expect(res.valueOrNull!.tipos.single.marcas.single.modelos, hasLength(1));
    });

    test('un fallo devuelve Err y no revienta', () async {
      final api = _ApiFake({})..falla = true;

      final res = await VehiculoService(api).catalogo();

      expect(res.isSuccess, isFalse);
    });
  });
}

class _ApiFake extends Fake implements ApiClient {
  _ApiFake(this.datos);

  final Map<String, dynamic> datos;
  bool falla = false;
  int llamadas = 0;
  final List<String> rutas = [];

  @override
  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic data)? parse,
  }) async {
    llamadas++;
    rutas.add(path);
    if (falla) {
      return const Err(Failure('sin conexión', kind: FailureKind.network));
    }
    return Ok<T>(parse!(datos));
  }
}

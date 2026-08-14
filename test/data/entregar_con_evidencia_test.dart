import 'package:app_conductor/data/repositories/pedido_repository.dart';
import 'package:app_conductor/data/services/api_client.dart';
import 'package:app_conductor/data/services/api_result.dart';
import 'package:app_conductor/data/services/pedido_service.dart';
import 'package:app_conductor/data/services/session_storage.dart';
import 'package:app_conductor/domain/models/estado_pedido.dart';
import 'package:app_conductor/domain/models/sesion.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Si la evidencia no sube, **el pedido no se marca entregado**.
///
/// El `Result` de `registrarEvidencia` se descartaba con un `await` a secas. Con
/// datos móviles malos —que es el caso normal en la calle— la foto se perdía en
/// silencio y el pedido quedaba `ENTREGADO` sin evidencia: justo el registro con
/// el que se resuelve una disputa. Y sin esto no hay nada que reintentar, porque
/// el estado ya habría avanzado.
void main() {
  late List<String> llamadas;
  late PedidoRepository repo;

  /// Adaptador que responde según la ruta y apunta el orden de las llamadas.
  DioAdapter adaptador({required int estadoEvidencia}) =>
      DioAdapter(llamadas, estadoEvidencia: estadoEvidencia);

  void montar({required int estadoEvidencia}) {
    llamadas = [];
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://ejemplo.test/Api',
        validateStatus: (s) => s != null && s < 500,
      ),
    )..httpClientAdapter = adaptador(estadoEvidencia: estadoEvidencia);
    repo = PedidoRepository(PedidoService(ApiClient(_SesionVacia(), dio: dio)));
  }

  test('con la evidencia fallando, el pedido no avanza a ENTREGADO', () async {
    montar(estadoEvidencia: 500);

    final res = await repo.entregar(
      7,
      foto: MultipartFile.fromString('x', filename: 'e.jpg'),
      coordenadas: const LatLng(9.35, -75.95),
    );

    expect(res, isA<Err<dynamic>>());
    // Lo importante: `avanzar` no se llegó a llamar.
    expect(llamadas, ['/pedidos/7/evidencia']);
  });

  test('el reintento reenvía y con éxito sí avanza', () async {
    montar(estadoEvidencia: 200);

    final res = await repo.entregar(
      7,
      foto: MultipartFile.fromString('x', filename: 'e.jpg'),
      coordenadas: const LatLng(9.35, -75.95),
    );

    expect(res.isSuccess, isTrue);
    expect(res.valueOrNull?.estado, EstadoPedido.entregado);
    expect(llamadas, ['/pedidos/7/evidencia', '/pedidos/7/avanzar']);
  });

  test('entregar sin foto ni coordenadas sigue avanzando directo', () async {
    // El cambio solo cubre "había evidencia y no subió"; una entrega sin foto no
    // pasa por el endpoint de evidencia y no cambia de comportamiento.
    montar(estadoEvidencia: 500);

    final res = await repo.entregar(7);

    expect(res.isSuccess, isTrue);
    expect(llamadas, ['/pedidos/7/avanzar']);
  });

  test('informa el progreso de la subida', () async {
    montar(estadoEvidencia: 200);
    final avisos = <(int, int)>[];

    await repo.entregar(
      7,
      foto: MultipartFile.fromString('x' * 4096, filename: 'e.jpg'),
      onProgreso: (enviados, total) => avisos.add((enviados, total)),
    );

    expect(avisos, isNotEmpty, reason: 'Dio tiene que reportar onSendProgress');
  });
}

/// Adaptador mínimo: no sale a la red y deja ver en qué orden se llamó a qué.
class DioAdapter implements HttpClientAdapter {
  DioAdapter(this.llamadas, {required this.estadoEvidencia});

  final List<String> llamadas;
  final int estadoEvidencia;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Drenar el cuerpo es lo que hace que Dio emita `onSendProgress`.
    if (requestStream != null) await requestStream.drain<void>();

    llamadas.add(options.path);

    if (options.path.endsWith('/evidencia')) {
      return ResponseBody.fromString('', estadoEvidencia);
    }
    return ResponseBody.fromString(
      '{"id":7,"estado":"ENTREGADO"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SesionVacia implements SessionStorage {
  @override
  Future<void> borrar() async {}

  @override
  Future<Sesion?> leer() async => null;

  @override
  Future<void> guardar(Sesion sesion) async {}
}

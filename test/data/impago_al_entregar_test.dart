import 'package:app_conductor/data/repositories/pedido_repository.dart';
import 'package:app_conductor/data/services/api_client.dart';
import 'package:app_conductor/data/services/pedido_service.dart';
import 'package:app_conductor/data/services/session_storage.dart';
import 'package:app_conductor/domain/models/sesion.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// «El cliente no me pagó la compra»: lo que sale del teléfono al entregar.
///
/// La regla que vigila este archivo, y la que se pierde con un `false` puesto
/// por defecto: **«no dijo nada» y «dijo que sí le pagaron» son cosas
/// distintas**. El backend las distingue, y mandar la clave siempre convertiría
/// el silencio de todos los conductores en una afirmación sobre cada cliente.
void main() {
  late List<Map<String, dynamic>> cuerpos;
  late PedidoRepository repo;

  setUp(() {
    cuerpos = [];
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://ejemplo.test/Api',
        validateStatus: (s) => s != null && s < 500,
      ),
    )..httpClientAdapter = _Adaptador(cuerpos);
    repo = PedidoRepository(PedidoService(ApiClient(_SesionVacia(), dio: dio)));
  });

  test('sin declarar nada, la marca no viaja', () async {
    await repo.entregar(7);

    expect(cuerpos.single.containsKey('adelantoNoReembolsado'), isFalse,
        reason: 'la clave ausente es "no dijo nada"; un false sería una '
            'afirmación que nadie hizo');
  });

  test('declarado, viaja como true', () async {
    await repo.entregar(7, adelantoNoReembolsado: true);

    expect(cuerpos.single['adelantoNoReembolsado'], isTrue);
  });

  test('la entrega se completa igual con la marca y sin ella', () async {
    final conMarca = await repo.entregar(7, adelantoNoReembolsado: true);
    final sinMarca = await repo.entregar(8);

    expect(conMarca.isSuccess, isTrue);
    expect(sinMarca.isSuccess, isTrue,
        reason: 'la marca es opcional y nunca puede bloquear una entrega');
  });

  test('convive con el importe realmente cobrado, que es otro dato', () async {
    await repo.entregar(7,
        montoRealProductos: 31500, adelantoNoReembolsado: true);

    expect(cuerpos.single['montoRealProductos'], 31500);
    expect(cuerpos.single['adelantoNoReembolsado'], isTrue);
  });
}

class _Adaptador implements HttpClientAdapter {
  _Adaptador(this.cuerpos);

  final List<Map<String, dynamic>> cuerpos;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    cuerpos.add(Map<String, dynamic>.from(options.data as Map));
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

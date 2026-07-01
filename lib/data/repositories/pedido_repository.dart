import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import '../../domain/models/propuesta_tarifa.dart';
import '../services/api_result.dart';
import '../services/pedido_service.dart';

/// Fuente de verdad de los pedidos para el conductor. REST es autoritativo
/// para estado/ganancia (design D7).
class PedidoRepository {
  PedidoRepository(this._service);

  final PedidoService _service;

  Future<Result<Pedido>> detalle(int pedidoId) => _service.detalle(pedidoId);

  Future<Result<List<Pedido>>> mios() => _service.mios();

  Future<Result<PropuestaTarifa>> proponer(int pedidoId, {double? valor}) =>
      _service.proponer(pedidoId, valor: valor);

  Future<Result<Pedido>> avanzar(int pedidoId, EstadoPedido destino) =>
      _service.cambiarEstado(pedidoId, destino.wire);

  Future<Result<Pedido>> entregar(
    int pedidoId, {
    MultipartFile? foto,
    LatLng? coordenadas,
  }) =>
      _service.entregar(pedidoId, foto: foto, coordenadas: coordenadas);

  /// Deriva el pedido activo del conductor (último no terminado) desde el
  /// historial — no hay endpoint dedicado (design Q4).
  Future<Pedido?> pedidoActivo() async {
    final res = await _service.mios();
    if (res case Ok<List<Pedido>>(value: final lista)) {
      for (final p in lista) {
        if (p.estado.estaActivo && p.tieneConductor) return p;
      }
    }
    return null;
  }
}

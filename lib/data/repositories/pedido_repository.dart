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

  /// Pedidos asignados al conductor (historial/ingresos).
  Future<Result<List<Pedido>>> mios() => _service.asignados();

  Future<Result<PropuestaTarifa>> proponer(int pedidoId, {double? valor}) =>
      _service.proponer(pedidoId, valor: valor);

  Future<Result<Pedido>> avanzar(int pedidoId, EstadoPedido destino) =>
      _service.avanzarEstado(pedidoId, destino.wire);

  /// Ofertas de pedidos cercanos para el conductor en línea (fallback de sondeo).
  Future<Result<List<Pedido>>> ofertas() => _service.ofertas();

  Future<Result<void>> reportarPosicion(int pedidoId, LatLng punto) =>
      _service.reportarPosicion(pedidoId, punto);

  /// Marca entregado: primero sube la evidencia (si hay) y luego avanza el
  /// estado a ENTREGADO (la comisión se genera en el backend en ese paso).
  Future<Result<Pedido>> entregar(
    int pedidoId, {
    MultipartFile? foto,
    LatLng? coordenadas,
  }) async {
    if (foto != null || coordenadas != null) {
      await _service.registrarEvidencia(pedidoId, foto: foto, coordenadas: coordenadas);
    }
    return _service.avanzarEstado(pedidoId, EstadoPedido.entregado.wire);
  }

  /// Deriva el pedido activo del conductor (último no terminado) desde el
  /// historial — no hay endpoint dedicado (design Q4).
  Future<Pedido?> pedidoActivo() async {
    final res = await _service.asignados();
    if (res case Ok<List<Pedido>>(value: final lista)) {
      for (final p in lista) {
        if (p.estado.estaActivo && p.tieneConductor) return p;
      }
    }
    return null;
  }
}

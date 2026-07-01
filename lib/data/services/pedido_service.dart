import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/pedido.dart';
import '../../domain/models/propuesta_tarifa.dart';
import '../models/api_mappers.dart';
import 'api_client.dart';
import 'api_result.dart';

/// Cliente de los endpoints de pedidos usados por el conductor.
class PedidoService {
  PedidoService(this._api);

  final ApiClient _api;

  /// Detalle de un pedido (entrante o activo).
  Future<Result<Pedido>> detalle(int pedidoId) {
    return _api.get<Pedido>('/pedidos/$pedidoId', parse: ApiMappers.pedido);
  }

  /// Historial de pedidos del conductor autenticado.
  Future<Result<List<Pedido>>> mios() {
    return _api.get<List<Pedido>>('/pedidos/mios', parse: ApiMappers.pedidos);
  }

  /// Envía una propuesta: sin `valor` (o igual a la sugerida) acepta; con un
  /// `valor` distinto es contraoferta (design D4).
  Future<Result<PropuestaTarifa>> proponer(int pedidoId, {double? valor}) {
    return _api.post<PropuestaTarifa>(
      '/pedidos/$pedidoId/propuestas',
      body: {if (valor != null) 'valor': valor},
      parse: ApiMappers.propuesta,
    );
  }

  /// Avanza el estado del pedido (EN_COMPRA → EN_CAMINO). El backend valida la
  /// transición y responde 409 si no es permitida.
  Future<Result<Pedido>> cambiarEstado(int pedidoId, String estadoWire) {
    return _api.patch<Pedido>(
      '/pedidos/$pedidoId/estado',
      body: {'estado': estadoWire},
      parse: ApiMappers.pedido,
    );
  }

  /// Marca el pedido como entregado con evidencia opcional (foto + coordenadas).
  /// La entrega dispara la comisión en el backend (idempotente).
  Future<Result<Pedido>> entregar(
    int pedidoId, {
    MultipartFile? foto,
    LatLng? coordenadas,
  }) {
    return _api.postMultipart<Pedido>(
      '/pedidos/$pedidoId/entregar',
      fields: {
        if (foto != null) 'foto': foto,
        if (coordenadas != null) 'lat': coordenadas.latitude,
        if (coordenadas != null) 'lng': coordenadas.longitude,
      },
      parse: ApiMappers.pedido,
    );
  }
}

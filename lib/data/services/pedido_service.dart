import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/calificacion.dart';
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

  /// Calificación que el conductor recibió en un pedido (`/mi-calificacion`):
  /// devuelve la calificación o `null` (204) si aún no lo calificaron.
  Future<Result<Calificacion?>> miCalificacion(int pedidoId) {
    return _api.get<Calificacion?>('/pedidos/$pedidoId/mi-calificacion', parse: (data) {
      if (data == null || (data is String && data.isEmpty)) return null;
      return ApiMappers.calificacion(data);
    });
  }

  /// Historial de pedidos asignados al conductor autenticado.
  /// (`/pedidos/mios` es solo para CLIENTE; el conductor usa `/pedidos/asignados`.)
  Future<Result<List<Pedido>>> asignados() {
    return _api.get<List<Pedido>>('/pedidos/asignados', parse: ApiMappers.pedidos);
  }

  /// Pedido en curso del conductor (endpoint ligero `/pedidos/activo`): devuelve
  /// un solo pedido o `null` (204). Evita descargar todo el historial en cada
  /// tick del sondeo.
  Future<Result<Pedido?>> activo() {
    return _api.get<Pedido?>('/pedidos/activo', parse: (data) {
      if (data == null || (data is String && data.isEmpty)) return null;
      return ApiMappers.pedido(data);
    });
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
  /// Avanza el estado del pedido (EN_COMPRA → EN_CAMINO → ENTREGADO). El backend
  /// valida la transición y responde 409 si no es permitida.
  /// Contrato real: `POST /pedidos/{id}/avanzar` con body `{estado}`.
  Future<Result<Pedido>> avanzarEstado(int pedidoId, String estadoWire) {
    return _api.post<Pedido>(
      '/pedidos/$pedidoId/avanzar',
      body: {'estado': estadoWire},
      parse: ApiMappers.pedido,
    );
  }

  /// Registra la evidencia de entrega (foto opcional + coordenadas) vía
  /// `POST /pedidos/{id}/evidencia` (multipart). Es independiente del avance de
  /// estado a ENTREGADO (ver [avanzarEstado]).
  Future<Result<void>> registrarEvidencia(
    int pedidoId, {
    MultipartFile? foto,
    LatLng? coordenadas,
  }) {
    return _api.postMultipart<void>(
      '/pedidos/$pedidoId/evidencia',
      fields: {
        if (foto != null) 'foto': foto,
        if (coordenadas != null) 'lat': coordenadas.latitude,
        if (coordenadas != null) 'lng': coordenadas.longitude,
      },
    );
  }

  /// Publica la posición del conductor durante el pedido activo vía REST
  /// `POST /pedidos/{id}/posicion` (el backend la retransmite por STOMP al
  /// cliente en `/topic/pedido/{id}`).
  Future<Result<void>> reportarPosicion(int pedidoId, LatLng punto) {
    return _api.post<void>(
      '/pedidos/$pedidoId/posicion',
      body: {'lat': punto.latitude, 'lng': punto.longitude},
    );
  }

  /// Ofertas de pedidos cercanos disponibles para el conductor en línea
  /// (fallback de sondeo cuando el push FCM no está disponible).
  Future<Result<List<Pedido>>> ofertas() {
    return _api.get<List<Pedido>>('/pedidos/ofertas', parse: ApiMappers.pedidos);
  }

  /// Rechaza una oferta: deja de aparecer en el sondeo y baja la tasa de
  /// aceptación del conductor (`POST /pedidos/{id}/rechazar`).
  Future<Result<void>> rechazar(int pedidoId) {
    return _api.post<void>('/pedidos/$pedidoId/rechazar');
  }
}

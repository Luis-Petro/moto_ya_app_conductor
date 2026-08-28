import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/calificacion.dart';
import '../../domain/models/oferta.dart';
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
    return _api.get<Calificacion?>(
      '/pedidos/$pedidoId/mi-calificacion',
      parse: (data) {
        if (data == null || (data is String && data.isEmpty)) return null;
        return ApiMappers.calificacion(data);
      },
    );
  }

  /// Historial de pedidos asignados al conductor autenticado.
  /// (`/pedidos/mios` es solo para CLIENTE; el conductor usa `/pedidos/asignados`.)
  Future<Result<List<Pedido>>> asignados() {
    return _api.get<List<Pedido>>(
      '/pedidos/asignados',
      parse: ApiMappers.pedidos,
    );
  }

  /// Pedido en curso del conductor (endpoint ligero `/pedidos/activo`): devuelve
  /// un solo pedido o `null` (204). Evita descargar todo el historial en cada
  /// tick del sondeo.
  Future<Result<Pedido?>> activo() {
    return _api.get<Pedido?>(
      '/pedidos/activo',
      parse: (data) {
        if (data == null || (data is String && data.isEmpty)) return null;
        return ApiMappers.pedido(data);
      },
    );
  }

  /// TODOS los pedidos en curso del conductor (`/pedidos/activos`), del más
  /// antiguo al más reciente.
  ///
  /// Con el pedido encadenado encendido puede llevar más de uno, y `/activo`
  /// devuelve solo el más reciente: el segundo quedaba invisible justo después
  /// de aceptarlo. Sigue siendo ligero — como mucho dos o tres pedidos.
  Future<Result<List<Pedido>>> activos() {
    return _api.get<List<Pedido>>(
      '/pedidos/activos',
      parse: ApiMappers.pedidos,
    );
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
  /// Contrato real: `POST /pedidos/{id}/avanzar` con body
  /// `{estado, montoRealProductos?}`.
  ///
  /// [montoRealProductos] es **lo que el negocio cobró de verdad** y solo tiene
  /// efecto al pasar a `ENTREGADO`. Va **fuera del JSON cuando es nulo** y no como
  /// `null`: el backend distingue "no lo declaró" de un valor, y mandar la clave
  /// vacía es la forma silenciosa de convertir lo primero en lo segundo.
  Future<Result<Pedido>> avanzarEstado(int pedidoId, String estadoWire,
      {double? montoRealProductos}) {
    return _api.post<Pedido>(
      '/pedidos/$pedidoId/avanzar',
      body: {
        'estado': estadoWire,
        if (montoRealProductos != null)
          'montoRealProductos': montoRealProductos,
      },
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
    void Function(int enviados, int total)? onProgreso,
  }) {
    return _api.postMultipart<void>(
      '/pedidos/$pedidoId/evidencia',
      fields: {
        if (foto != null) 'foto': foto,
        if (coordenadas != null) 'lat': coordenadas.latitude,
        if (coordenadas != null) 'lng': coordenadas.longitude,
      },
      onProgreso: onProgreso,
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

  /// Ofertas dirigidas y vigentes para el conductor en línea (fallback de sondeo
  /// del canal STOMP). Cada una trae la ventana del servidor (`segundosRestantes`).
  Future<Result<List<Oferta>>> ofertas() {
    return _api.get<List<Oferta>>(
      '/pedidos/ofertas',
      parse: ApiMappers.ofertas,
    );
  }

  /// Rechaza una oferta: deja de aparecer en el sondeo y baja la tasa de
  /// aceptación del conductor (`POST /pedidos/{id}/rechazar`).
  Future<Result<void>> rechazar(int pedidoId) {
    return _api.post<void>('/pedidos/$pedidoId/rechazar');
  }
}

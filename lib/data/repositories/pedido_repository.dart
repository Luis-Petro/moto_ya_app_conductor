import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/calificacion.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/oferta.dart';
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

  /// Calificación recibida por el conductor en un pedido (o `null` si no lo han
  /// calificado todavía).
  Future<Calificacion?> calificacionRecibida(int pedidoId) async {
    final res = await _service.miCalificacion(pedidoId);
    return res.valueOrNull;
  }

  /// Pedidos asignados al conductor (historial/ingresos).
  Future<Result<List<Pedido>>> mios() => _service.asignados();

  Future<Result<PropuestaTarifa>> proponer(int pedidoId, {double? valor}) =>
      _service.proponer(pedidoId, valor: valor);

  Future<Result<Pedido>> avanzar(int pedidoId, EstadoPedido destino) =>
      _service.avanzarEstado(pedidoId, destino.wire);

  /// Ofertas dirigidas y vigentes para el conductor en línea (fallback de sondeo).
  Future<Result<List<Oferta>>> ofertas() => _service.ofertas();

  /// Rechaza una oferta (deja de aparecer en el sondeo; baja la tasa de aceptación).
  Future<Result<void>> rechazar(int pedidoId) => _service.rechazar(pedidoId);

  Future<Result<void>> reportarPosicion(int pedidoId, LatLng punto) =>
      _service.reportarPosicion(pedidoId, punto);

  /// Marca entregado: primero sube la evidencia (si hay) y luego avanza el
  /// estado a ENTREGADO (la comisión se genera en el backend en ese paso).
  ///
  /// **Si la evidencia no sube, el pedido no avanza.** Antes el `Result` de
  /// `registrarEvidencia` se descartaba: con datos móviles malos, la foto se
  /// perdía en silencio y el pedido quedaba `ENTREGADO` **sin evidencia**, que es
  /// justo el registro con el que se resuelve una disputa. Y sin esto no hay nada
  /// que reintentar: el estado ya habría avanzado.
  /// [montoRealProductos] es opcional y **no bloquea la entrega**: si el conductor
  /// no lo declara, el pedido se entrega igual y el backend se queda con el
  /// estimado del catálogo.
  Future<Result<Pedido>> entregar(
    int pedidoId, {
    MultipartFile? foto,
    LatLng? coordenadas,
    double? montoRealProductos,
    bool? adelantoNoReembolsado,
    void Function(int enviados, int total)? onProgreso,
  }) async {
    if (foto != null || coordenadas != null) {
      final evidencia = await _service.registrarEvidencia(
        pedidoId,
        foto: foto,
        coordenadas: coordenadas,
        onProgreso: onProgreso,
      );
      if (evidencia case Err<void>(failure: final f)) return Err<Pedido>(f);
    }
    return _service.avanzarEstado(pedidoId, EstadoPedido.entregado.wire,
        montoRealProductos: montoRealProductos,
        adelantoNoReembolsado: adelantoNoReembolsado);
  }

  /// Pedido activo del conductor (último no terminado) vía el endpoint ligero
  /// `/pedidos/activo`: transfiere un solo pedido o vacío por tick, en lugar de
  /// todo el historial. Si el pedido devuelto ya no tiene conductor asignado
  /// (caso límite), se descarta.
  Future<Pedido?> pedidoActivo() async {
    final res = await _service.activo();
    if (res case Ok<Pedido?>(value: final p)) {
      if (p != null && p.estado.estaActivo && p.tieneConductor) return p;
    }
    return null;
  }

  /// TODOS los pedidos en curso del conductor, del más antiguo al más reciente.
  ///
  /// Un fallo devuelve `null`, no una lista vacía: son cosas distintas y
  /// confundirlas hace que un corte de red se vea como "ya no tienes pedidos" y
  /// borre de la pantalla un pedido que el conductor está haciendo.
  Future<List<Pedido>?> pedidosActivos() async {
    final res = await _service.activos();
    return res.when(
      ok: (lista) => lista
          .where((p) => p.estado.estaActivo && p.tieneConductor)
          .toList(growable: false),
      err: (_) => null,
    );
  }
}

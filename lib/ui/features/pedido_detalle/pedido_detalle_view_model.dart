import 'package:flutter/foundation.dart';

import '../../../data/repositories/pedido_repository.dart';
import '../../../domain/models/calificacion.dart';
import '../../../domain/models/pedido.dart';

/// Estado del detalle de un pedido del historial del conductor: carga el pedido
/// completo (incluye distancia/ruta) y la calificación que recibió, si existe.
class PedidoDetalleViewModel extends ChangeNotifier {
  PedidoDetalleViewModel(this._pedidos, this.pedidoId, {Pedido? inicial})
      : pedido = inicial;

  final PedidoRepository _pedidos;
  final int pedidoId;

  bool cargando = true;
  String? error;

  /// Pedido mostrado. Puede venir precargado desde el historial (respuesta
  /// instantánea) y se refresca con el detalle del backend.
  Pedido? pedido;

  /// Calificación que el conductor recibió en este pedido (null si no lo han
  /// calificado o aún no cargó).
  Calificacion? calificacion;

  Future<void> cargar() async {
    cargando = true;
    error = null;
    notifyListeners();

    final res = await _pedidos.detalle(pedidoId);
    if (res.isSuccess) {
      pedido = res.valueOrNull ?? pedido;
    } else if (pedido == null) {
      error = 'No pudimos cargar el pedido.';
    }

    // La calificación solo aplica a pedidos entregados; si falla, se ignora.
    if (pedido?.estado.esFinal ?? false) {
      calificacion = await _pedidos.calificacionRecibida(pedidoId);
    }

    cargando = false;
    notifyListeners();
  }
}

import 'pedido.dart';

/// Oferta dirigida vigente para el conductor: el pedido más la ventana de
/// respuesta que calcula el servidor (`GET /pedidos/ofertas`). `segundosRestantes`
/// es inmune al reloj del teléfono; `expiraEnMillis` (epoch) sirve para revalidar.
class Oferta {
  const Oferta({
    required this.pedido,
    required this.expiraEnMillis,
    required this.segundosRestantes,
  });

  final Pedido pedido;
  final int expiraEnMillis;
  final int segundosRestantes;

  int get pedidoId => pedido.id;
}

/// Tipo de evento que llega por la cola personal STOMP `/user/queue/ofertas`.
enum TipoEventoOferta {
  nuevo,
  expirada,
  tomado,
  cancelado;

  static TipoEventoOferta fromWire(String? tipo) {
    switch (tipo) {
      case 'OFERTA_EXPIRADA':
        return TipoEventoOferta.expirada;
      case 'PEDIDO_TOMADO':
        return TipoEventoOferta.tomado;
      case 'PEDIDO_CANCELADO':
        return TipoEventoOferta.cancelado;
      case 'PEDIDO_NUEVO':
      default:
        return TipoEventoOferta.nuevo;
    }
  }

  /// Los eventos que deben cerrar una oferta abierta (ya no es tomable).
  bool get cierraOferta => this != TipoEventoOferta.nuevo;
}

/// Evento del ciclo de vida de una oferta en tiempo real.
class EventoOferta {
  const EventoOferta(this.tipo, this.pedidoId);
  final TipoEventoOferta tipo;
  final int pedidoId;
}

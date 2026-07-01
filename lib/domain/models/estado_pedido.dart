/// Estados del pedido (espejo del enum del backend `EstadoPedido`).
enum EstadoPedido {
  pendiente('PENDIENTE', 'Pendiente'),
  buscandoConductor('BUSCANDO_CONDUCTOR', 'Buscando'),
  propuestaEnviada('PROPUESTA_ENVIADA', 'Propuesta'),
  aceptado('ACEPTADO', 'Aceptado'),
  enCompra('EN_COMPRA', 'En compra'),
  enCamino('EN_CAMINO', 'En camino'),
  entregado('ENTREGADO', 'Entregado'),
  cancelado('CANCELADO', 'Cancelado');

  const EstadoPedido(this.wire, this.label);

  final String wire;
  final String label;

  static EstadoPedido fromWire(String? value) {
    return EstadoPedido.values.firstWhere(
      (e) => e.wire == value,
      orElse: () => EstadoPedido.pendiente,
    );
  }

  bool get esFinal =>
      this == EstadoPedido.entregado || this == EstadoPedido.cancelado;

  /// Hay un pedido en curso que el cliente puede seguir.
  bool get estaActivo => !esFinal;

  /// Pasos visibles en la barra de tracking (excluye PROPUESTA_ENVIADA/PENDIENTE
  /// y CANCELADO, que no forman parte del camino feliz).
  static const List<EstadoPedido> pasosTracking = [
    EstadoPedido.buscandoConductor,
    EstadoPedido.aceptado,
    EstadoPedido.enCompra,
    EstadoPedido.enCamino,
    EstadoPedido.entregado,
  ];

  /// Posición del estado dentro de `pasosTracking` (para pintar progreso).
  int get indiceTracking {
    switch (this) {
      case EstadoPedido.pendiente:
      case EstadoPedido.buscandoConductor:
      case EstadoPedido.propuestaEnviada:
        return 0;
      case EstadoPedido.aceptado:
        return 1;
      case EstadoPedido.enCompra:
        return 2;
      case EstadoPedido.enCamino:
        return 3;
      case EstadoPedido.entregado:
        return 4;
      case EstadoPedido.cancelado:
        return -1;
    }
  }
}

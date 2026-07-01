/// Propuesta de tarifa emitida por un conductor sobre un pedido.
class PropuestaTarifa {
  const PropuestaTarifa({
    required this.id,
    required this.pedidoId,
    required this.conductorId,
    required this.valorPropuesto,
    required this.esContraoferta,
    required this.estado,
    this.fecha,
  });

  final int id;
  final int pedidoId;
  final int conductorId;
  final double valorPropuesto;
  final bool esContraoferta;

  /// Estado de la propuesta (ENVIADA, ACEPTADA, RECHAZADA).
  final String estado;
  final DateTime? fecha;

  bool get estaVigente => estado == 'ENVIADA';
}

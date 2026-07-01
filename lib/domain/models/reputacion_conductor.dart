/// Métricas de reputación de un conductor (espejo de `MetricasConductor`).
class ReputacionConductor {
  const ReputacionConductor({
    this.calificacion,
    this.tasaAceptacion,
    this.tasaCancelacion,
    this.tiempoRespuestaSeg,
  });

  final double? calificacion;
  final double? tasaAceptacion;
  final double? tasaCancelacion;
  final int? tiempoRespuestaSeg;
}

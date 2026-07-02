/// Calificación recibida en un pedido (espejo de la entidad backend
/// `Calificacion`). Solo los campos que la app conductor necesita mostrar.
class Calificacion {
  const Calificacion({
    required this.puntaje,
    this.comentario,
    this.creadoEn,
  });

  /// Puntaje de 1 a 5 estrellas.
  final int puntaje;
  final String? comentario;
  final DateTime? creadoEn;

  bool get tieneComentario => comentario?.trim().isNotEmpty ?? false;
}

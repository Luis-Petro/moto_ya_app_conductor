/// Rol del usuario (espejo del enum del backend `Rol`).
enum Rol {
  cliente('CLIENTE'),
  conductor('CONDUCTOR'),
  administrador('ADMINISTRADOR');

  const Rol(this.wire);

  final String wire;

  static Rol fromWire(String? value) {
    return Rol.values.firstWhere(
      (r) => r.wire == value,
      orElse: () => Rol.cliente,
    );
  }
}

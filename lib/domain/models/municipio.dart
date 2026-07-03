import 'package:latlong2/latlong.dart';

/// Municipio donde opera la plataforma (catálogo administrado por el operador;
/// las apps solo reciben los activos).
class Municipio {
  const Municipio({
    required this.id,
    required this.departamento,
    required this.nombre,
    this.centro,
  });

  final int id;
  final String departamento;
  final String nombre;

  /// Centro del casco urbano: default de mapas y respaldo cuando no hay GPS.
  final LatLng? centro;

  /// Texto para mostrar: "San Bernardo del Viento, Córdoba".
  String get etiqueta => '$nombre, $departamento';
}

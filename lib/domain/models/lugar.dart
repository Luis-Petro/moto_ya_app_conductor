import 'package:latlong2/latlong.dart';

/// Punto de interés del catálogo del municipio: la tienda, la droguería, el
/// parque que la gente usa como referencia.
///
/// En un municipio sin nomenclatura confiable esto *es* la dirección: nadie dice
/// "carrera 7 #12-34", dice "la droguería de la esquina del parque".
class Lugar {
  const Lugar({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.punto,
    this.referencia,
  });

  final int id;
  final String nombre;
  final CategoriaLugar categoria;
  final LatLng punto;

  /// Cómo llegar cuando el punto no basta: "segundo piso", "portón azul".
  final String? referencia;
}

enum CategoriaLugar {
  comercio,
  restaurante,
  farmacia,
  supermercado,
  salud,
  educacion,
  publico,
  referencia,
  otro;

  static CategoriaLugar desdeApi(String? valor) {
    return switch (valor) {
      'COMERCIO' => CategoriaLugar.comercio,
      'RESTAURANTE' => CategoriaLugar.restaurante,
      'FARMACIA' => CategoriaLugar.farmacia,
      'SUPERMERCADO' => CategoriaLugar.supermercado,
      'SALUD' => CategoriaLugar.salud,
      'EDUCACION' => CategoriaLugar.educacion,
      'PUBLICO' => CategoriaLugar.publico,
      'REFERENCIA' => CategoriaLugar.referencia,
      _ => CategoriaLugar.otro,
    };
  }

  /// Icono con el que se reconoce el tipo de lugar de un vistazo en la lista.
  String get emoji => switch (this) {
        CategoriaLugar.comercio => '🏪',
        CategoriaLugar.restaurante => '🍽️',
        CategoriaLugar.farmacia => '💊',
        CategoriaLugar.supermercado => '🛒',
        CategoriaLugar.salud => '🏥',
        CategoriaLugar.educacion => '🏫',
        CategoriaLugar.publico => '🏛️',
        CategoriaLugar.referencia => '📍',
        CategoriaLugar.otro => '📌',
      };
}

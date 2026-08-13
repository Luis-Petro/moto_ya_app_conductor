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
    this.forma,
  });

  final int id;
  final String nombre;
  final CategoriaLugar categoria;

  /// **El punto de encuentro con el conductor**, no el centro del sitio. Un
  /// parque no tiene puerta: aunque el lugar tenga [forma], aquí es donde se
  /// espera, y es lo que se copia al pedido.
  final LatLng punto;

  /// Cómo llegar cuando el punto no basta: "segundo piso", "portón azul".
  final String? referencia;

  /// Vértices que delimitan el área, o `null` —lo normal— si el lugar es un
  /// punto. El anillo llega **abierto**: el último vértice no repite el primero.
  ///
  /// Solo la trae `GET /lugares/mapa`; el autocompletar no, porque es una lista
  /// de texto. Es presentación: nada del pedido depende de ella.
  final List<LatLng>? forma;

  /// `true` si hay un área que dibujar. Un anillo de menos de tres vértices no
  /// es un área, así que cuenta como no tenerla.
  bool get tieneForma => forma != null && forma!.length >= 3;
}

/// Tipo de sitio. El orden es el de la lista en el selector: agrupado por tipo,
/// lo más pedido arriba.
///
/// Cualquier valor que el backend añada y esta app no conozca cae en [otro]
/// (ver [desdeApi]): una app vieja muestra el lugar con un pin genérico en vez
/// de romperse, que es lo que tiene que pasar cuando el backend va por delante
/// de lo que hay instalado en los teléfonos.
enum CategoriaLugar {
  // Compras
  comercio,
  supermercado,
  panaderia,
  ferreteria,
  papeleria,
  // Comida
  restaurante,
  // Salud
  farmacia,
  veterinaria,
  salud,
  // Servicios y trámites
  barberia,
  taller,
  corresponsal,
  hotel,
  // Instituciones
  educacion,
  publico,
  // Sin actividad comercial
  referencia,
  otro;

  static CategoriaLugar desdeApi(String? valor) {
    return switch (valor) {
      'COMERCIO' => CategoriaLugar.comercio,
      'SUPERMERCADO' => CategoriaLugar.supermercado,
      'PANADERIA' => CategoriaLugar.panaderia,
      'FERRETERIA' => CategoriaLugar.ferreteria,
      'PAPELERIA' => CategoriaLugar.papeleria,
      'RESTAURANTE' => CategoriaLugar.restaurante,
      'FARMACIA' => CategoriaLugar.farmacia,
      'VETERINARIA' => CategoriaLugar.veterinaria,
      'SALUD' => CategoriaLugar.salud,
      'BARBERIA' => CategoriaLugar.barberia,
      'TALLER' => CategoriaLugar.taller,
      'CORRESPONSAL' => CategoriaLugar.corresponsal,
      'HOTEL' => CategoriaLugar.hotel,
      'EDUCACION' => CategoriaLugar.educacion,
      'PUBLICO' => CategoriaLugar.publico,
      'REFERENCIA' => CategoriaLugar.referencia,
      _ => CategoriaLugar.otro,
    };
  }

  /// Icono con el que se reconoce el tipo de lugar de un vistazo en la lista.
  String get emoji => switch (this) {
        CategoriaLugar.comercio => '🏪',
        CategoriaLugar.supermercado => '🛒',
        CategoriaLugar.panaderia => '🥖',
        CategoriaLugar.ferreteria => '🔧',
        CategoriaLugar.papeleria => '🖨️',
        CategoriaLugar.restaurante => '🍽️',
        CategoriaLugar.farmacia => '💊',
        CategoriaLugar.veterinaria => '🐾',
        CategoriaLugar.salud => '🏥',
        CategoriaLugar.barberia => '💈',
        CategoriaLugar.taller => '🛠️',
        CategoriaLugar.corresponsal => '💵',
        CategoriaLugar.hotel => '🏨',
        CategoriaLugar.educacion => '🏫',
        CategoriaLugar.publico => '🏛️',
        CategoriaLugar.referencia => '📍',
        CategoriaLugar.otro => '📌',
      };

  /// Nombre en es_CO, como lo diría alguien del municipio.
  String get etiqueta => switch (this) {
        CategoriaLugar.comercio => 'Tienda o comercio',
        CategoriaLugar.supermercado => 'Supermercado',
        CategoriaLugar.panaderia => 'Panadería',
        CategoriaLugar.ferreteria => 'Ferretería',
        CategoriaLugar.papeleria => 'Papelería',
        CategoriaLugar.restaurante => 'Restaurante',
        CategoriaLugar.farmacia => 'Droguería',
        CategoriaLugar.veterinaria => 'Veterinaria',
        CategoriaLugar.salud => 'Salud',
        CategoriaLugar.barberia => 'Barbería o peluquería',
        CategoriaLugar.taller => 'Taller',
        CategoriaLugar.corresponsal => 'Corresponsal o pagos',
        CategoriaLugar.hotel => 'Hotel o cabaña',
        CategoriaLugar.educacion => 'Colegio o educación',
        CategoriaLugar.publico => 'Sitio público',
        CategoriaLugar.referencia => 'Punto de referencia',
        CategoriaLugar.otro => 'Otro',
      };
}

/// El catálogo de vehículos que administra el panel: tipo → marca → modelo.
///
/// Sustituye a `catalogo_motos.dart`, que era una lista fija **compilada dentro
/// del binario**: añadir una marca eran dos APK y esperar a que la gente
/// actualice. Ahora se consulta al servidor, así que cargar una marca en el panel
/// la pone en el alta del día siguiente.
///
/// **El orden es el del servidor y no se reordena.** El catálogo está ordenado
/// por uso real en el municipio; alfabéticamente, la marca que conduce la mitad
/// de la flota queda por detrás de las que casi nadie tiene.
library;

import 'package:flutter/material.dart';

/// Silueta de respaldo del tipo, cuando una fila no tiene imagen.
///
/// **Juego cerrado, y eso es lo que permite que el panel cree un tipo nuevo sin
/// publicar una versión de esta app**: la clave se traduce a un glifo que ya va
/// dentro del binario, y una que esta app no conozca cae en [IconoVehiculo.otro].
///
/// La silueta es un **glifo y no un bitmap**, siguiendo el precedente del
/// proyecto: el marcador de producto saca su icono de `CategoriaServicio.icon`,
/// que también vive en el dominio con su `IconData`. Sale nítido a cualquier
/// tamaño, hereda el color, no pesa un byte del presupuesto de imágenes y es el
/// mismo lenguaje visual que el placeholder del panel.
enum IconoVehiculo {
  moto(Icons.two_wheeler_rounded),
  bicicleta(Icons.pedal_bike_rounded),
  tricimoto(Icons.electric_rickshaw_rounded),
  carro(Icons.directions_car_rounded),
  aPie(Icons.directions_walk_rounded),
  otro(Icons.commute_rounded);

  const IconoVehiculo(this.silueta);

  /// El glifo con el que se pinta una fila sin imagen.
  final IconData silueta;

  /// Traduce la clave del servidor. Lo desconocido cae en [otro] **sin lanzar**:
  /// un tipo creado después de publicar esta app tiene que ofrecerse igual.
  static IconoVehiculo desde(String? clave) => switch (clave) {
        'MOTO' => moto,
        'BICICLETA' => bicicleta,
        'TRICIMOTO' => tricimoto,
        'CARRO' => carro,
        'A_PIE' => aPie,
        _ => otro,
      };
}

/// Un modelo concreto: es lo único que se referencia al dar de alta el perfil.
class ModeloVehiculo {
  const ModeloVehiculo({
    required this.id,
    required this.nombre,
    this.imagenUrl,
  });

  final int id;
  final String nombre;

  /// Foto opcional. Sin ella se pinta la silueta del **tipo**, nunca el logo de
  /// su marca: seis modelos del mismo fabricante saldrían con la misma imagen,
  /// que es exactamente lo que no distingue nada.
  final String? imagenUrl;
}

class MarcaVehiculo {
  const MarcaVehiculo({
    required this.id,
    required this.nombre,
    this.imagenUrl,
    this.modelos = const [],
  });

  final int id;
  final String nombre;
  final String? imagenUrl;
  final List<ModeloVehiculo> modelos;
}

class TipoVehiculo {
  const TipoVehiculo({
    required this.id,
    required this.nombre,
    required this.icono,
    this.imagenUrl,
    this.marcas = const [],
  });

  final int id;
  final String nombre;
  final IconoVehiculo icono;
  final String? imagenUrl;
  final List<MarcaVehiculo> marcas;
}

/// El árbol vigente completo, tal como llega en una sola respuesta.
class CatalogoVehiculos {
  const CatalogoVehiculos({this.tipos = const []});

  final List<TipoVehiculo> tipos;

  /// Un catálogo vacío no es un error: es una lista vacía, y el paso del
  /// vehículo cae a texto libre igual que si la consulta hubiera fallado.
  bool get estaVacio => tipos.isEmpty;
}

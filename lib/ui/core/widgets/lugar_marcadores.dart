import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../domain/models/lugar.dart';
import '../theme/app_colors.dart';

/// Zoom a partir del cual se dibujan los lugares.
///
/// Más lejos que esto, unos cientos de marcadores se convierten en una mancha
/// que tapa el mapa en vez de ayudar a ubicarse.
const double zoomMinimoLugares = 15;

/// Zoom a partir del cual el marcador crece y se le pone el nombre al lado.
///
/// Entre [zoomMinimoLugares] y este umbral solo va el punto con su icono: en un
/// casco urbano los comercios están a media cuadra unos de otros y, a esa
/// distancia, cuatro burbujas grandes con etiqueta se tapan entre sí.
const double zoomNombresLugares = 16.5;

/// Alto de la etiqueta con el nombre, contando su separación del icono.
const double _altoEtiqueta = 20;

/// Cuánto mide el círculo del marcador a un zoom dado. Crece con el zoom
/// porque al acercarse sobra sitio y el icono se lee mejor.
double tamanoMarcador(double zoom) {
  if (zoom >= 17.5) return 36;
  if (zoom >= zoomNombresLugares) return 30;
  return 22;
}

/// Icono de cada categoría. Vive en la capa de UI y no en el modelo porque
/// `domain` no depende de Flutter (ver convenciones de capas).
IconData iconoDeCategoria(CategoriaLugar c) => switch (c) {
      CategoriaLugar.comercio => Icons.storefront,
      CategoriaLugar.supermercado => Icons.shopping_cart,
      CategoriaLugar.panaderia => Icons.bakery_dining,
      CategoriaLugar.ferreteria => Icons.hardware,
      CategoriaLugar.papeleria => Icons.print,
      CategoriaLugar.restaurante => Icons.restaurant,
      CategoriaLugar.farmacia => Icons.local_pharmacy,
      CategoriaLugar.veterinaria => Icons.pets,
      CategoriaLugar.salud => Icons.local_hospital,
      CategoriaLugar.barberia => Icons.content_cut,
      CategoriaLugar.taller => Icons.build,
      CategoriaLugar.corresponsal => Icons.payments,
      CategoriaLugar.hotel => Icons.hotel,
      CategoriaLugar.educacion => Icons.school,
      CategoriaLugar.publico => Icons.account_balance,
      CategoriaLugar.referencia => Icons.place,
      CategoriaLugar.otro => Icons.push_pin,
    };

/// Color de fondo del marcador, por función y no por categoría.
///
/// Cinco cubos, no diecisiete colores: a 22 px un círculo no comunica un matiz,
/// y con diecisiete tonos el mapa deja de tener un código de color y pasa a
/// tener confeti.
///
/// El naranja de marca se reserva para **de dónde se pide** (comida y mercado,
/// que son las categorías del propio pedido). Es el mismo naranja de los pines
/// de recogida y entrega y de la posición del usuario, así que repartirlo entre
/// todas las categorías haría que esos tres —los únicos que el cliente
/// *necesita* encontrar— dejaran de destacar. Servicios y trámites van en
/// [AppColors.accent]; las referencias, en gris.
Color colorDeCategoria(CategoriaLugar c) => switch (c) {
      CategoriaLugar.comercio ||
      CategoriaLugar.supermercado ||
      CategoriaLugar.panaderia ||
      CategoriaLugar.restaurante =>
        AppColors.primary,
      CategoriaLugar.farmacia || CategoriaLugar.veterinaria => AppColors.success,
      CategoriaLugar.salud => AppColors.danger,
      CategoriaLugar.ferreteria ||
      CategoriaLugar.papeleria ||
      CategoriaLugar.barberia ||
      CategoriaLugar.taller ||
      CategoriaLugar.corresponsal ||
      CategoriaLugar.hotel ||
      CategoriaLugar.educacion ||
      CategoriaLugar.publico =>
        AppColors.accent,
      CategoriaLugar.referencia || CategoriaLugar.otro => AppColors.inkMuted,
    };

/// Marcadores del catálogo para una capa de `flutter_map`, dimensionados según
/// el [zoom] actual.
///
/// [onTap] es opcional: en el selector de punto sirve para elegir el lugar de
/// un toque; en un mapa de solo lectura los lugares son referencia visual.
///
/// [permitirNombres] en `false` deja solo los iconos por mucho que se acerque el
/// mapa. Es para los mapas de 150–220 px de las pantallas de detalle: ahí las
/// etiquetas se solapan con la ruta del pedido, que es lo que esa pantalla ha
/// venido a mostrar.
List<Marker> marcadoresDeLugares(
  List<Lugar> lugares, {
  required double zoom,
  ValueChanged<Lugar>? onTap,
  bool permitirNombres = true,
}) {
  final tamano = tamanoMarcador(zoom);
  final conNombre = permitirNombres && zoom >= zoomNombresLugares;
  final alto = tamano + (conNombre ? _altoEtiqueta : 0);
  return [
    for (final lugar in lugares)
      Marker(
        point: lugar.punto,
        // Con etiqueta el widget crece hacia abajo, así que se ancla el centro
        // del círculo (no el del widget) sobre la coordenada real del lugar.
        alignment: conNombre ? Alignment(0, -_altoEtiqueta / alto) : Alignment.center,
        width: conNombre ? 120 : tamano,
        height: alto,
        child: _MarcadorLugar(
          lugar: lugar,
          tamano: tamano,
          conNombre: conNombre,
          onTap: onTap,
        ),
      ),
  ];
}

/// Polígonos de los lugares que son un área, para una `PolygonLayer`.
///
/// Van **debajo** de los marcadores: el relleno no puede tapar un pin, y el
/// marcador del punto sigue siendo el que lleva el icono, el nombre y el toque
/// para elegir el lugar.
///
/// El relleno es el color de la categoría a baja opacidad y el borde el mismo
/// color: un parque relleno de verde translúcido se reconoce como superficie sin
/// competir con la ruta del pedido, que va encima y en naranja.
List<Polygon> poligonosDeLugares(List<Lugar> lugares) {
  return [
    for (final lugar in lugares)
      if (lugar.tieneForma)
        Polygon(
          points: lugar.forma!,
          color: colorDeCategoria(lugar.categoria).withValues(alpha: 0.15),
          borderColor: colorDeCategoria(lugar.categoria).withValues(alpha: 0.7),
          borderStrokeWidth: 1.5,
        ),
  ];
}

class _MarcadorLugar extends StatelessWidget {
  const _MarcadorLugar({
    required this.lugar,
    required this.tamano,
    required this.conNombre,
    this.onTap,
  });

  final Lugar lugar;
  final double tamano;
  final bool conNombre;
  final ValueChanged<Lugar>? onTap;

  @override
  Widget build(BuildContext context) {
    final circulo = Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: colorDeCategoria(lugar.categoria),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(
        iconoDeCategoria(lugar.categoria),
        size: tamano * 0.52,
        color: AppColors.surface,
      ),
    );

    final contenido = conNombre
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [circulo, _Etiqueta(nombre: lugar.nombre)],
          )
        : circulo;

    // El tooltip cubre el caso sin etiqueta: el nombre sigue disponible
    // manteniendo pulsado, sin ocupar sitio en el mapa.
    final conTooltip = Tooltip(message: lugar.nombre, child: contenido);
    if (onTap == null) {
      return conTooltip;
    }
    return GestureDetector(onTap: () => onTap!(lugar), child: conTooltip);
  }
}

/// Nombre del lugar bajo el icono, sobre una pastilla clara para que se lea
/// encima de cualquier parte del mapa.
class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.nombre});
  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

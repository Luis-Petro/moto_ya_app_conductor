import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../config/env.dart';
import '../theme/app_colors.dart';

/// Zoom mínimo de cualquier mapa de la app.
///
/// Más lejos que esto el municipio entero cabe en una uña y el mapa deja de
/// servir para ubicar nada.
const double zoomMinimoMapa = 11;

/// Zoom máximo de cualquier mapa de la app: el último nivel con tiles reales de
/// OpenStreetMap. Pasado este punto el mapa se quedaba en gris.
const double zoomMaximoMapa = 19;

/// Capa de tiles OpenStreetMap configurable (ADR-008).
TileLayer osmTileLayer() {
  return TileLayer(
    urlTemplate: Env.osmTileUrl,
    userAgentPackageName: 'co.motoya.conductor',
    // `maxNativeZoom`, no `maxZoom`: con `maxZoom` la capa deja de pintarse por
    // encima del valor y el mapa queda gris con los marcadores flotando.
    // `maxNativeZoom` es hasta dónde se piden tiles; más allá reescala el
    // último nivel, así que siempre se ve algo.
    maxNativeZoom: 19,
  );
}

/// Marcador con pin de color de marca.
Marker pinMarker(LatLng punto, {required IconData icon, Color? color}) {
  return Marker(
    point: punto,
    width: 44,
    height: 44,
    alignment: Alignment.topCenter,
    child: Icon(icon, color: color ?? AppColors.primary, size: 36),
  );
}

/// Marcador circular del propio usuario.
Marker usuarioMarker(LatLng punto) {
  return Marker(
    point: punto,
    width: 22,
    height: 22,
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    ),
  );
}

/// Atribución OSM (requerida por la licencia).
///
/// La ODbL exige el crédito a *contributors*, no solo al proyecto.
Widget osmAttribution() {
  return const Align(
    alignment: Alignment.bottomRight,
    child: Padding(
      padding: EdgeInsets.all(4),
      child: Text('© OpenStreetMap contributors',
          style: TextStyle(fontSize: 9, color: AppColors.inkMuted)),
    ),
  );
}

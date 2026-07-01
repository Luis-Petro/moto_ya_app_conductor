import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../config/env.dart';
import '../theme/app_colors.dart';

/// Capa de tiles OpenStreetMap configurable (ADR-008).
TileLayer osmTileLayer() {
  return TileLayer(
    urlTemplate: Env.osmTileUrl,
    userAgentPackageName: 'co.motoya.app_cliente',
    maxZoom: 19,
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
Widget osmAttribution() {
  return const Align(
    alignment: Alignment.bottomRight,
    child: Padding(
      padding: EdgeInsets.all(4),
      child: Text('© OpenStreetMap',
          style: TextStyle(fontSize: 9, color: AppColors.inkMuted)),
    ),
  );
}

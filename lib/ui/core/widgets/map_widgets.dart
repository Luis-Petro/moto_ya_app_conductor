import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:latlong2/latlong.dart';

import '../../../config/env.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/map_tile_cache.dart';
import '../theme/app_colors.dart';

/// Zoom mínimo de cualquier mapa de la app.
///
/// Más lejos que esto el municipio entero cabe en una uña y el mapa deja de
/// servir para ubicar nada.
const double zoomMinimoMapa = 11;

/// Zoom máximo de cualquier mapa de la app: el último nivel con tiles reales.
/// Pasado este punto el mapa se quedaba en gris.
const double zoomMaximoMapa = 19;

/// Encuadre inicial que abarca [puntos], **con la lista vacía resuelta**.
///
/// `LatLngBounds.fromPoints` lanza si la lista viene vacía. Eso ocurrió de verdad
/// en el mapa de demanda del Inicio (celdas vacías y ubicación aún sin resolver)
/// y en release se vio como un **rectángulo gris mudo**: el `ErrorWidget` por
/// defecto no escribe nada, así que el reporte llegó como "el home se queda en
/// blanco" en vez de como una excepción.
///
/// Un mapa centrado en el municipio es un desenlace honesto; una excepción en
/// medio del `build` no lo es.
CameraFit encuadreDePuntos(
  List<LatLng> puntos, {
  EdgeInsets padding = const EdgeInsets.all(28),
  LatLng respaldo = LocationService.fallbackCenter,
  double zoomRespaldo = 14,
}) {
  if (puntos.isEmpty) {
    return CameraFit.coordinates(
      coordinates: [respaldo],
      maxZoom: zoomRespaldo,
    );
  }
  return CameraFit.bounds(
    bounds: LatLngBounds.fromPoints(puntos),
    padding: padding,
  );
}

/// Capa de tiles configurable (ADR-008).
///
/// Los datos son de OpenStreetMap; quien los dibuja y los sirve lo decide
/// [Env.tileUrl] (Geoapify en producción).
///
/// Usa caché en disco ([MapTileCache]) cuando está disponible: cada tile visto
/// se guarda y se reutiliza. Aquí importa más que en la app cliente —el mapa
/// está abierto todo el domicilio y el municipio es siempre el mismo—, y con
/// proveedor de cuota diaria cada tile reutilizado es un crédito que no se
/// gasta. Si la caché no se inicializó, cae al proveedor de red estándar.
TileLayer osmTileLayer() {
  final store = MapTileCache.store;
  return TileLayer(
    urlTemplate: Env.tileUrl,
    userAgentPackageName: 'com.zumbeo.conductor',
    // `maxNativeZoom`, no `maxZoom`: con `maxZoom` la capa deja de pintarse por
    // encima del valor y el mapa queda gris con los marcadores flotando.
    // `maxNativeZoom` es hasta dónde se piden tiles; más allá reescala el
    // último nivel, así que siempre se ve algo.
    maxNativeZoom: 19,
    // Solo los tiles visibles. El default (`panBuffer: 1`) carga un anillo extra
    // alrededor de la pantalla: pasa de ~15 tiles por apertura a ~35, y el plan
    // del proveedor limita las peticiones por segundo, así que ese anillo se
    // traduce en cuadros grises justo al abrir el mapa. El precio es ver tiles
    // cargando al panear, y solo la primera vez en cada zona: lo demás sale de
    // la caché de disco.
    panBuffer: 0,
    tileProvider: store != null
        ? CachedTileProvider(store: store, maxStale: const Duration(days: 30))
        : NetworkTileProvider(),
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

/// Atribución del mapa (requerida por licencia, no es decorativa).
///
/// La ODbL exige el crédito a *contributors*, no solo al proyecto. Cuando los
/// tiles los sirve Geoapify hay que acreditarlo también —lo piden sus términos
/// de uso gratuito—, y solo entonces: con tiles propios en R2 no hay tercero a
/// quien nombrar.
///
/// Va sobre una placa blanca translúcida porque un texto gris de 9 px sin fondo
/// se pierde según el tile que le toque debajo, y esto es justo lo que no puede
/// quedar ilegible.
Widget osmAttribution() {
  return Align(
    alignment: Alignment.bottomRight,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Text(
            Env.tilesGeoapify
                ? '© OpenStreetMap contributors · Powered by Geoapify'
                : '© OpenStreetMap contributors',
            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
          ),
        ),
      ),
    ),
  );
}

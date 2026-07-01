import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationOutcome { ok, denied, deniedForever, serviceDisabled, error }

class LocationResult {
  const LocationResult(this.outcome, [this.position]);
  final LocationOutcome outcome;
  final LatLng? position;

  bool get isOk => outcome == LocationOutcome.ok && position != null;
}

/// Envuelve `geolocator` con manejo explícito de permisos (mobile-design:
/// siempre degradar con gracia cuando el permiso se deniega).
class LocationService {
  /// Ubicación por defecto: La Ceja, Antioquia (centro del piloto), usada como
  /// respaldo si no hay permiso de ubicación.
  static const LatLng fallbackCenter = LatLng(6.0289, -75.4309);

  Future<LocationResult> obtenerUbicacion() async {
    try {
      final servicioActivo = await Geolocator.isLocationServiceEnabled();
      if (!servicioActivo) {
        return const LocationResult(LocationOutcome.serviceDisabled);
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied) {
        return const LocationResult(LocationOutcome.denied);
      }
      if (permiso == LocationPermission.deniedForever) {
        return const LocationResult(LocationOutcome.deniedForever);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LocationResult(
          LocationOutcome.ok, LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      return const LocationResult(LocationOutcome.error);
    }
  }

  /// Dirección legible aproximada para una coordenada (geocodificación inversa).
  /// Devuelve null si el servicio no responde.
  Future<String?> direccionDe(LatLng punto) async {
    try {
      final marcas =
          await placemarkFromCoordinates(punto.latitude, punto.longitude);
      if (marcas.isEmpty) return null;
      final p = marcas.first;
      final partes = <String?>[
        (p.street != null && p.street!.isNotEmpty) ? p.street : p.name,
        p.subLocality?.isNotEmpty == true ? p.subLocality : p.locality,
      ].where((s) => s != null && s.isNotEmpty).cast<String>().toList();
      return partes.isEmpty ? null : partes.join(', ');
    } catch (_) {
      return null;
    }
  }
}

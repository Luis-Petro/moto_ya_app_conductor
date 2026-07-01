import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Reporta la ubicación del conductor con conciencia de batería (design D3):
/// emite por cambio de distancia (`distanceFilter`) en lugar de un stream de
/// alta frecuencia. El consumidor arranca al ponerse en línea / abrir el pedido
/// activo y DEBE llamar a [stop] al salir (anti-patrón: dejar el GPS activo).
class LocationReporter {
  StreamSubscription<Position>? _sub;

  bool get activo => _sub != null;

  /// Comienza a reportar posiciones. [onPosition] recibe cada punto significativo.
  void start(void Function(LatLng punto) onPosition, {int distanceFilterM = 30}) {
    stop();
    _sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterM,
      ),
    ).listen(
      (pos) => onPosition(LatLng(pos.latitude, pos.longitude)),
      onError: (_) {/* permiso revocado / GPS off: se detiene con gracia */},
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
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
  ///
  /// Con [background] = true el reporte sobrevive a que la app pase a segundo
  /// plano o se bloquee la pantalla: en Android levanta un servicio en primer
  /// plano (notificación persistente) y en iOS habilita las actualizaciones en
  /// background. Es lo que mantiene al conductor "cercano" para el matching
  /// aunque no tenga la app abierta; sin esto Android corta el GPS y a los pocos
  /// minutos su ubicación caduca (`MATCHING_UBICACION_TTL_SEGUNDOS`) y deja de
  /// recibir ofertas.
  void start(
    void Function(LatLng punto) onPosition, {
    int distanceFilterM = 30,
    bool background = false,
  }) {
    stop();
    _sub = Geolocator.getPositionStream(
      locationSettings: _settings(distanceFilterM, background),
    ).listen(
      (pos) => onPosition(LatLng(pos.latitude, pos.longitude)),
      onError: (_) {/* permiso revocado / GPS off: se detiene con gracia */},
    );
  }

  LocationSettings _settings(int distanceFilterM, bool background) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterM,
          // El servicio en primer plano (lo declara geolocator_android) mantiene
          // el GPS vivo con la app minimizada mientras el conductor está en línea.
          foregroundNotificationConfig: background
              ? const ForegroundNotificationConfig(
                  notificationTitle: 'motoYa · en línea',
                  notificationText:
                      'Compartiendo tu ubicación para recibir pedidos cercanos.',
                  notificationChannelName: 'Ubicación en línea',
                  enableWakeLock: true,
                  setOngoing: true,
                )
              : null,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterM,
          activityType: ActivityType.automotiveNavigation,
          allowBackgroundLocationUpdates: background,
          showBackgroundLocationIndicator: background,
          pauseLocationUpdatesAutomatically: false,
        );
      default:
        return LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterM,
        );
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}

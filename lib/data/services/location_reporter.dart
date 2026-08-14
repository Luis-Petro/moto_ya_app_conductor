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
  Timer? _heartbeat;
  LatLng? _ultima;
  DateTime? _ultimoReporteOk;

  bool get activo => _sub != null;

  /// Margen tras el cual el backend considera caducada la ubicación y deja de
  /// ofrecer pedidos (`MATCHING_UBICACION_TTL_SEGUNDOS`, default 300s). Es el
  /// default del servidor copiado aquí: el backend no lo expone y un conductor
  /// que se cree en línea mientras el matching ya lo descartó no tiene forma de
  /// saber por qué no le llegan ofertas.
  static const Duration margenVisibilidad = Duration(seconds: 300);

  /// Instante del último reporte que el backend **aceptó**. No basta con que el
  /// GPS emita: si el POST falla, la posición no llega y el conductor deja de
  /// ser visible igual. Lo marca quien hace la petición, que es el único que
  /// conoce su desenlace.
  DateTime? get ultimoReporteOk => _ultimoReporteOk;

  void marcarReporteOk() => _ultimoReporteOk = DateTime.now();

  /// El conductor lleva más del margen sin conseguir reportar, así que el
  /// backend ya no lo ve. Falso mientras el reporte no está activo: fuera de
  /// línea no hay nada que avisar.
  bool get reporteCaducado {
    if (!activo) return false;
    // `start` lo siembra, así que "nunca consiguió reportar desde que se puso en
    // línea" también caduca. Tratarlo como "aún no se sabe" dejaría el caso peor
    // —el que nunca reporta— sin ningún aviso.
    final ultimo = _ultimoReporteOk;
    if (ultimo == null) return false;
    return DateTime.now().difference(ultimo) > margenVisibilidad;
  }

  /// Latido que reenvía la última posición conocida aunque el conductor no se
  /// mueva. Debe ser holgadamente menor que `MATCHING_UBICACION_TTL_SEGUNDOS`
  /// (default backend 300s) para que un conductor en línea pero quieto no
  /// caduque y desaparezca del conteo de "conductores cerca" / del matching.
  static const Duration _intervaloLatido = Duration(seconds: 60);

  /// Comienza a reportar posiciones. [onPosition] recibe cada punto significativo.
  ///
  /// El stream de GPS solo emite al desplazarse [distanceFilterM] metros, así que
  /// un conductor quieto dejaría de reportar; para evitarlo se añade un **latido**
  /// ([_intervaloLatido]) que reenvía la última ubicación conocida y mantiene la
  /// frescura que exige el backend. [inicial] siembra ese latido para no depender
  /// del primer fix del stream (útil justo al ponerse en línea).
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
    LatLng? inicial,
  }) {
    stop();
    _ultima = inicial;
    _ultimoReporteOk = DateTime.now();
    _sub = Geolocator.getPositionStream(
      locationSettings: _settings(distanceFilterM, background),
    ).listen(
      (pos) {
        _ultima = LatLng(pos.latitude, pos.longitude);
        onPosition(_ultima!);
      },
      // Permiso revocado, GPS apagado o servicio en primer plano terminado por
      // el sistema: se suelta la suscripción para que `activo` diga la verdad.
      // Si siguiera en pie, quien pregunte creería que se está reportando.
      onError: (_) => stop(),
      onDone: stop,
    );
    // Latido: reenvía la última ubicación conocida aunque el GPS no emita
    // (conductor quieto), para no caducar frente al TTL del backend.
    _heartbeat = Timer.periodic(_intervaloLatido, (_) {
      final punto = _ultima;
      if (punto != null) onPosition(punto);
    });
  }

  LocationSettings _settings(int distanceFilterM, bool background) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterM,
          // El servicio en primer plano (lo declara geolocator_android) mantiene
          // el GPS vivo con la app minimizada mientras el conductor está en línea.
          //
          // Su notificación vive en un canal aparte del de ofertas y del de
          // avisos: es un indicador permanente, no un aviso, y mezclarlo con los
          // pedidos haría que silenciar lo uno silenciara lo otro.
          //
          // Ese canal lo crea el propio plugin con el id `geolocator_channel_01`
          // e `IMPORTANCE_NONE` —silencioso y sin heads-up, justo lo que hace
          // falta—. El id es privado del plugin y no se puede sustituir; lo
          // único que decidimos es el nombre visible en los Ajustes, de ahí
          // `notificationChannelName`. Crear un canal propio que nada usaría
          // solo añadiría una entrada muerta a los Ajustes del sistema.
          foregroundNotificationConfig: background
              ? const ForegroundNotificationConfig(
                  notificationTitle: 'Zumbeo · en línea',
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
    _heartbeat?.cancel();
    _heartbeat = null;
    _ultima = null;
    _ultimoReporteOk = null;
  }
}

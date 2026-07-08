import 'package:geolocator/geolocator.dart';

import 'push_service.dart';

/// Resultado del chequeo de ubicación para operar en línea.
enum PermisoUbicacion { ok, servicioApagado, denegado, denegadoPermanente }

/// Resultado del chequeo de notificaciones para operar en línea.
enum PermisoNotificaciones { ok, denegado }

class ResultadoPermisos {
  const ResultadoPermisos(this.ubicacion, this.notificaciones);
  final PermisoUbicacion ubicacion;
  final PermisoNotificaciones notificaciones;

  bool get todoOk =>
      ubicacion == PermisoUbicacion.ok &&
      notificaciones == PermisoNotificaciones.ok;
}

/// Centraliza los permisos que el conductor DEBE tener activos para recibir
/// pedidos: ubicación (el matching es por cercanía; sin GPS es invisible) y
/// notificaciones (el aviso de oferta llega por push). Solicita el permiso del
/// SO cuando falta y expone el chequeo estructurado para que la UI decida qué
/// mostrar (prompt del SO vs. enviar a Ajustes cuando quedó denegado).
class PermisosService {
  PermisosService(this._push);

  final PushService _push;

  Future<ResultadoPermisos> asegurarParaOperar() async {
    return ResultadoPermisos(
      await _asegurarUbicacion(),
      await _asegurarNotificaciones(),
    );
  }

  Future<PermisoUbicacion> _asegurarUbicacion() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return PermisoUbicacion.servicioApagado;
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) return PermisoUbicacion.denegado;
    if (permiso == LocationPermission.deniedForever) {
      return PermisoUbicacion.denegadoPermanente;
    }
    return PermisoUbicacion.ok;
  }

  Future<PermisoNotificaciones> _asegurarNotificaciones() async {
    return await _push.asegurarPermiso()
        ? PermisoNotificaciones.ok
        : PermisoNotificaciones.denegado;
  }

  /// Ajustes de la app (permiso denegado permanentemente / notificaciones).
  Future<void> abrirConfiguracionApp() => Geolocator.openAppSettings();

  /// Ajustes de ubicación del sistema (servicio de GPS apagado).
  Future<void> abrirConfiguracionUbicacion() =>
      Geolocator.openLocationSettings();
}

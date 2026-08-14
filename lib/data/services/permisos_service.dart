import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'notificacion_local_service.dart';
import 'push_service.dart';

/// Resultado del chequeo de ubicación para operar en línea.
enum PermisoUbicacion { ok, servicioApagado, denegado, denegadoPermanente }

/// Resultado del chequeo de notificaciones para operar en línea.
enum PermisoNotificaciones { ok, denegado }

/// Resultado del chequeo de la exención de optimización de batería.
///
/// `noAplica` no es un fallo: en iOS y en las versiones de Android que no la
/// exponen, la pregunta no existe y no hay nada que mostrarle al conductor.
enum PermisoBateria { ok, denegado, noAplica }

class ResultadoPermisos {
  const ResultadoPermisos(this.ubicacion, this.notificaciones, this.bateria);
  final PermisoUbicacion ubicacion;
  final PermisoNotificaciones notificaciones;
  final PermisoBateria bateria;

  bool get todoOk =>
      ubicacion == PermisoUbicacion.ok &&
      notificaciones == PermisoNotificaciones.ok;

  /// Puede operar pero le pueden faltar avisos con la app cerrada. No bloquea:
  /// la exención es una decisión del conductor y el sistema puede ni ofrecerla.
  bool get puedePerderAvisos => bateria == PermisoBateria.denegado;
}

/// Centraliza los permisos que el conductor DEBE tener activos para recibir
/// pedidos: ubicación (el matching es por cercanía; sin GPS es invisible),
/// notificaciones (el aviso de oferta llega por push) y la exención de la
/// optimización de batería (sin ella el sistema mata el proceso al minimizar la
/// app y no llegan ni el push ni el sondeo). Solicita el permiso del SO cuando
/// falta y expone el chequeo estructurado para que la UI decida qué mostrar
/// (prompt del SO vs. enviar a Ajustes cuando quedó denegado).
class PermisosService {
  PermisosService(this._push, this._avisos);

  final PushService _push;
  final NotificacionLocalService _avisos;

  Future<ResultadoPermisos> asegurarParaOperar() async {
    final ubicacion = await _asegurarUbicacion();
    final notificaciones = await _asegurarNotificaciones();
    // Solo se pide con las notificaciones ya concedidas: encadenar dos diálogos
    // del sistema sin haber explicado nada es como se consiguen dos rechazos.
    final bateria = notificaciones == PermisoNotificaciones.ok
        ? await _asegurarBateria()
        : await estadoBateria();
    return ResultadoPermisos(ubicacion, notificaciones, bateria);
  }

  /// ¿Ya está concedido el permiso de ubicación? **No lo solicita.**
  ///
  /// Lo usa la pantalla para saber si tiene que explicar antes qué se va a
  /// compartir: las tiendas exigen que esa explicación aparezca *antes* del
  /// diálogo del sistema, y consultarlo con `asegurarParaOperar` lo dispararía.
  Future<bool> ubicacionYaConcedida() async {
    final permiso = await Geolocator.checkPermission();
    return permiso == LocationPermission.always ||
        permiso == LocationPermission.whileInUse;
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
    if (!await _push.asegurarPermiso()) return PermisoNotificaciones.denegado;
    // Android 14+ concede `USE_FULL_SCREEN_INTENT` de oficio solo a las apps de
    // llamadas y alarmas. Si el conductor lo niega, la oferta sigue sonando como
    // heads-up por el canal de timbre: se pide, no se exige.
    await _avisos.pedirPermisoPantallaCompleta();
    return PermisoNotificaciones.ok;
  }

  /// Estado de la exención **sin pedirla**, para pintar la fila de permisos.
  Future<PermisoBateria> estadoBateria() async {
    if (!_bateriaAplica) return PermisoBateria.noAplica;
    try {
      return await Permission.ignoreBatteryOptimizations.isGranted
          ? PermisoBateria.ok
          : PermisoBateria.denegado;
    } catch (_) {
      // El sistema no expone la pregunta: tratarlo como fallo mostraría un aviso
      // que el conductor no puede resolver.
      return PermisoBateria.noAplica;
    }
  }

  /// Ofrece el diálogo del sistema para salir de la optimización de batería.
  ///
  /// Devuelve el estado resultante y **nunca bloquea**: dejar a un conductor sin
  /// poder trabajar por una pantalla que su teléfono no muestra es peor que el
  /// problema que se quería resolver.
  Future<PermisoBateria> pedirExencionBateria() => _asegurarBateria();

  Future<PermisoBateria> _asegurarBateria() async {
    final actual = await estadoBateria();
    if (actual != PermisoBateria.denegado) return actual;
    try {
      final estado = await Permission.ignoreBatteryOptimizations.request();
      return estado.isGranted ? PermisoBateria.ok : PermisoBateria.denegado;
    } catch (_) {
      return PermisoBateria.noAplica;
    }
  }

  bool get _bateriaAplica => !kIsWeb && Platform.isAndroid;

  /// Ajustes de la app (permiso denegado permanentemente / notificaciones).
  Future<void> abrirConfiguracionApp() => Geolocator.openAppSettings();

  /// Ajustes de ubicación del sistema (servicio de GPS apagado).
  Future<void> abrirConfiguracionUbicacion() =>
      Geolocator.openLocationSettings();
}

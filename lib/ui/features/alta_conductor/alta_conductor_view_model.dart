import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../domain/models/conductor.dart';

/// Estado del alta del perfil de conductor.
class AltaConductorViewModel extends ChangeNotifier {
  AltaConductorViewModel(this._conductores, this._location);

  final ConductorRepository _conductores;
  final LocationService _location;

  bool cargando = true;
  bool guardando = false;
  bool subiendoDocumento = false;
  String? error;

  /// Ubicación inicial del conductor (requerida por el backend en el alta).
  LatLng _ubicacion = LocationService.fallbackCenter;

  Conductor? get conductor => _conductores.conductor;
  bool get perfilCompleto => _conductores.perfilCompleto;

  /// Resuelve el perfil actual y la ubicación al abrir la pantalla.
  Future<void> cargar() async {
    cargando = true;
    notifyListeners();
    await _conductores.cargar(forzar: true);
    final loc = await _location.obtenerUbicacion();
    if (loc.isOk) _ubicacion = loc.position!;
    cargando = false;
    notifyListeners();
  }

  Future<bool> guardar({
    required String licencia,
    required String vehiculo,
    required String placa,
  }) async {
    guardando = true;
    error = null;
    notifyListeners();
    final res = await _conductores.crearPerfil(
      licencia: licencia,
      vehiculo: vehiculo,
      placa: placa,
      ubicacion: _ubicacion,
    );
    guardando = false;
    final ok = res.isSuccess;
    if (!ok) error = res.when(ok: (_) => null, err: (f) => f.message);
    notifyListeners();
    return ok;
  }

  Future<bool> subirDocumento(File archivo) async {
    subiendoDocumento = true;
    notifyListeners();
    final multipart = await MultipartFile.fromFile(archivo.path);
    final res = await _conductores.subirDocumento(multipart);
    subiendoDocumento = false;
    final ok = res.isSuccess;
    if (!ok) error = res.when(ok: (_) => null, err: (f) => f.message);
    notifyListeners();
    return ok;
  }
}

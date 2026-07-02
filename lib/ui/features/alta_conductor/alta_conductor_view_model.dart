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
  String? error;

  /// Archivos elegidos localmente; se suben tras crear el perfil (los endpoints
  /// de documentos exigen que el conductor ya exista).
  File? cedula;
  File? papelesMoto;

  bool get tieneCedula => cedula != null;
  void elegirCedula(File f) {
    cedula = f;
    notifyListeners();
  }

  void elegirPapelesMoto(File f) {
    papelesMoto = f;
    notifyListeners();
  }

  /// Ubicación inicial del conductor (requerida por el backend en el alta).
  LatLng _ubicacion = LocationService.fallbackCenter;

  Conductor? get conductor => _conductores.conductor;
  bool get perfilCompleto => _conductores.perfilCompleto;

  /// Resuelve el perfil actual y libera la pantalla enseguida; la ubicación se
  /// resuelve en segundo plano (el GPS puede tardar y no debe bloquear el alta).
  Future<void> cargar() async {
    cargando = true;
    notifyListeners();
    await _conductores.cargar(forzar: true);
    cargando = false;
    notifyListeners();
    _resolverUbicacion(); // background: no se espera
  }

  Future<void> _resolverUbicacion() async {
    final loc = await _location.obtenerUbicacion();
    if (loc.isOk) _ubicacion = loc.position!;
  }

  /// Crea el perfil y sube los documentos (cédula obligatoria, papeles opcionales).
  /// El perfil queda PENDIENTE_VERIFICACION hasta que el admin lo habilite.
  Future<bool> guardar({
    required String licencia,
    required String vehiculo,
    required String placa,
  }) async {
    if (cedula == null) {
      error = 'Adjunta tu cédula para continuar';
      notifyListeners();
      return false;
    }
    guardando = true;
    error = null;
    notifyListeners();

    final res = await _conductores.crearPerfil(
      licencia: licencia,
      vehiculo: vehiculo,
      placa: placa,
      ubicacion: _ubicacion,
    );
    if (!res.isSuccess) {
      guardando = false;
      error = res.when(ok: (_) => null, err: (f) => f.message);
      notifyListeners();
      return false;
    }

    // Perfil creado: subir cédula (obligatoria) y papeles (opcionales).
    final cedulaMp = await MultipartFile.fromFile(cedula!.path);
    final resCedula = await _conductores.subirCedula(cedulaMp);
    if (!resCedula.isSuccess) {
      guardando = false;
      error = 'No pudimos subir la cédula. Reintenta.';
      notifyListeners();
      return false;
    }
    if (papelesMoto != null) {
      final papelesMp = await MultipartFile.fromFile(papelesMoto!.path);
      await _conductores.subirPapelesMoto(papelesMp); // opcional: no bloquea
    }

    guardando = false;
    notifyListeners();
    return true;
  }
}

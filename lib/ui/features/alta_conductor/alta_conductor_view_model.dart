import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/municipio_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../domain/models/conductor.dart';
import '../../../domain/models/municipio.dart';

/// Estado del alta del perfil de conductor.
class AltaConductorViewModel extends ChangeNotifier {
  AltaConductorViewModel(this._conductores, this._location, this._municipios,
      this._usuarios);

  final ConductorRepository _conductores;
  final LocationService _location;
  final MunicipioRepository _municipios;
  final UsuarioRepository _usuarios;

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
  /// Null mientras el GPS no responda; al guardar cae al centro del municipio.
  LatLng? _ubicacion;

  /// Municipios donde opera la plataforma y el elegido por el conductor.
  List<Municipio> municipios = const [];
  Municipio? municipioElegido;

  void elegirMunicipio(Municipio? m) {
    municipioElegido = m;
    notifyListeners();
  }

  Conductor? get conductor => _conductores.conductor;
  bool get perfilCompleto => _conductores.perfilCompleto;

  /// Resuelve el perfil actual y libera la pantalla enseguida; la ubicación se
  /// resuelve en segundo plano (el GPS puede tardar y no debe bloquear el alta).
  Future<void> cargar() async {
    cargando = true;
    notifyListeners();
    await _conductores.cargar(forzar: true);
    // Municipios disponibles: preselecciona el del usuario o el único que haya.
    municipios = (await _municipios.disponibles()).valueOrNull ?? const [];
    final u = (await _usuarios.perfil()).valueOrNull;
    municipioElegido = _municipios.porId(u?.municipioId) ??
        (municipios.isNotEmpty ? municipios.first : null);
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
  ///
  /// Reintentable: si el perfil ya quedó creado en un intento anterior (p. ej.
  /// falló la subida de la cédula), continúa directo con los documentos en vez
  /// de chocar con el 409 de "el conductor ya tiene perfil".
  Future<bool> guardar({
    String? licencia,
    required String vehiculo,
    required String placa,
  }) async {
    if (cedula == null) {
      error = 'Toma la foto de tu cédula para continuar';
      notifyListeners();
      return false;
    }
    guardando = true;
    error = null;
    notifyListeners();

    // Sin GPS, la ubicación inicial es el centro del municipio elegido (mejor
    // que un punto fijo: el matching busca conductores cerca de la recogida).
    final ubicacion = _ubicacion ??
        municipioElegido?.centro ??
        LocationService.fallbackCenter;

    if (_conductores.conductor == null) {
      final res = await _conductores.crearPerfil(
        licencia: (licencia == null || licencia.isEmpty) ? null : licencia,
        vehiculo: vehiculo,
        placa: placa,
        ubicacion: ubicacion,
      );
      if (!res.isSuccess) {
        final f = res.when(ok: (_) => null, err: (f) => f);
        if (f?.statusCode == 409) {
          // Ya existía (reintento tras un fallo a mitad): recargar y seguir.
          await _conductores.cargar(forzar: true);
        } else {
          guardando = false;
          error = f?.message;
          notifyListeners();
          return false;
        }
      }
    }

    // Perfil creado: subir cédula (obligatoria) y papeles (opcionales).
    final cedulaMp = await MultipartFile.fromFile(cedula!.path);
    final resCedula = await _conductores.subirCedula(cedulaMp);
    if (!resCedula.isSuccess) {
      guardando = false;
      error = resCedula.when(
        ok: (_) => null,
        err: (f) => f.isNetwork
            ? f.message
            : 'No pudimos subir la foto de tu cédula. Toca "Enviar" para reintentar.',
      );
      notifyListeners();
      return false;
    }
    if (papelesMoto != null) {
      final papelesMp = await MultipartFile.fromFile(papelesMoto!.path);
      await _conductores.subirPapelesMoto(papelesMp); // opcional: no bloquea
    }

    // Persistir el municipio del conductor (best-effort: no bloquea el alta).
    if (municipioElegido != null) {
      await _usuarios.actualizar(municipioId: municipioElegido!.id);
    }

    guardando = false;
    notifyListeners();
    return true;
  }
}

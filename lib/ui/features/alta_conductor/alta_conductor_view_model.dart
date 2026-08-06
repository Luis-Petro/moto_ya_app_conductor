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

  /// True cuando el backend rechazó con 403: el JWT guardado no tiene rol
  /// CONDUCTOR (sesión emitida antes de la promoción de rol). La pantalla debe
  /// cerrar sesión para forzar un login fresco.
  bool sesionInvalida = false;

  /// Archivos elegidos localmente; se suben tras crear el perfil (los endpoints
  /// de documentos exigen que el conductor ya exista).
  File? cedula;
  File? papelesMoto;
  File? selfie;
  File? fotoMoto;

  bool get tieneCedula => cedula != null;
  void elegirCedula(File f) {
    cedula = f;
    notifyListeners();
  }

  void elegirPapelesMoto(File f) {
    papelesMoto = f;
    notifyListeners();
  }

  void elegirSelfie(File f) {
    selfie = f;
    notifyListeners();
  }

  void elegirFotoMoto(File f) {
    fotoMoto = f;
    notifyListeners();
  }

  /// Los cuatro documentos que el admin exige para habilitar, y cuáles faltan.
  /// Cuenta lo ya subido en el servidor además de lo elegido en esta pantalla:
  /// quien vuelve al alta tras subir la cédula no debe volver a tomarla.
  static const int documentosRequeridos = 4;

  bool get _cedulaLista => cedula != null || (conductor?.tieneCedula ?? false);
  bool get _tarjetaLista =>
      papelesMoto != null || (conductor?.tieneTarjetaPropiedad ?? false);
  bool get _selfieLista => selfie != null || (conductor?.tieneSelfie ?? false);
  bool get _motoLista => fotoMoto != null || (conductor?.tieneFotoMoto ?? false);

  List<String> get documentosFaltantes => [
        if (!_cedulaLista) 'cédula',
        if (!_tarjetaLista) 'tarjeta de propiedad',
        if (!_selfieLista) 'selfie',
        if (!_motoLista) 'foto de la moto',
      ];

  int get documentosListos =>
      documentosRequeridos - documentosFaltantes.length;

  double get progresoDocumentos => documentosListos / documentosRequeridos;

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
          // 403 = JWT sin rol CONDUCTOR (sesión vieja): la salida es re-loguear.
          if (f?.statusCode == 403) {
            sesionInvalida = true;
            error =
                'Tu sesión quedó desactualizada. Inicia sesión de nuevo para continuar.';
          } else {
            error = f?.message;
          }
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
      final f = resCedula.when(ok: (_) => null, err: (f) => f);
      if (f?.statusCode == 403) {
        sesionInvalida = true;
        error =
            'Tu sesión quedó desactualizada. Inicia sesión de nuevo para continuar.';
      } else {
        error = (f?.isNetwork ?? false)
            ? f!.message
            : 'No pudimos subir la foto de tu cédula. Toca "Enviar" para reintentar.';
      }
      notifyListeners();
      return false;
    }
    // El resto no bloquea el alta: sin ellos el perfil se envía igual y el
    // admin no habilitará hasta tenerlos (la pantalla ya lo advierte). Cortar
    // aquí dejaría al conductor sin poder ni empezar.
    if (papelesMoto != null) {
      final mp = await MultipartFile.fromFile(papelesMoto!.path);
      await _conductores.subirPapelesMoto(mp);
    }
    if (selfie != null) {
      final mp = await MultipartFile.fromFile(selfie!.path);
      await _conductores.subirSelfie(mp);
    }
    if (fotoMoto != null) {
      final mp = await MultipartFile.fromFile(fotoMoto!.path);
      await _conductores.subirFotoMoto(mp);
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

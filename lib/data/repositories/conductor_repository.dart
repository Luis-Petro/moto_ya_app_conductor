import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/conductor.dart';
import '../../domain/models/demanda_zonas.dart';
import '../services/api_result.dart';
import '../services/conductor_service.dart';

/// Fuente de verdad del perfil y estado del conductor. Reactiva (ChangeNotifier)
/// para que la navegación (alta vs. inicio) y el gating de "En línea" respondan
/// a cambios de perfil/estado sin recargas manuales.
class ConductorRepository extends ChangeNotifier {
  ConductorRepository(this._service);

  final ConductorService _service;

  Conductor? _conductor;
  Conductor? get conductor => _conductor;

  bool get perfilCompleto => _conductor?.perfilCompleto ?? false;
  bool get enLinea => _conductor?.enLinea ?? false;
  bool get bloqueadoPorDeuda => _conductor?.bloqueadoPorDeuda ?? false;

  /// Carga el perfil. Un 404 significa "sin perfil de conductor" (debe darse de
  /// alta), no un error de red.
  Future<Result<Conductor>> cargar({bool forzar = false}) async {
    if (_conductor != null && !forzar) return Ok(_conductor!);
    final res = await _service.obtenerPerfil();
    if (res case Ok<Conductor>(value: final c)) {
      _conductor = c;
      notifyListeners();
    }
    return res;
  }

  Future<Result<Conductor>> crearPerfil({
    String? licencia,
    required String vehiculo,
    required String placa,
    required LatLng ubicacion,
  }) async {
    final res = await _service.crearPerfil(
        licencia: licencia, vehiculo: vehiculo, placa: placa, ubicacion: ubicacion);
    _guardarSiOk(res);
    return res;
  }

  /// Sube un documento y refresca el perfil (el endpoint devuelve `{url}`, no el
  /// conductor, así que recargamos para reflejar `documentoUrl`).
  Future<Result<void>> subirDocumento(MultipartFile archivo) async {
    final res = await _service.subirDocumento(archivo);
    if (res.isSuccess) await cargar(forzar: true);
    return res;
  }

  /// Sube la foto de perfil y refresca (el endpoint devuelve `{url}`, no el perfil).
  Future<Result<void>> subirFoto(MultipartFile archivo) async {
    final res = await _service.subirFoto(archivo);
    if (res.isSuccess) await cargar(forzar: true);
    return res;
  }

  /// Sube la cédula (obligatoria) y refresca el perfil.
  Future<Result<void>> subirCedula(MultipartFile archivo) async {
    final res = await _service.subirCedula(archivo);
    if (res.isSuccess) await cargar(forzar: true);
    return res;
  }

  /// Sube la tarjeta de propiedad de la moto y refresca el perfil.
  Future<Result<void>> subirPapelesMoto(MultipartFile archivo) async {
    final res = await _service.subirPapelesMoto(archivo);
    if (res.isSuccess) await cargar(forzar: true);
    return res;
  }

  /// Sube la selfie de verificación y refresca el perfil.
  Future<Result<void>> subirSelfie(MultipartFile archivo) async {
    final res = await _service.subirSelfie(archivo);
    if (res.isSuccess) await cargar(forzar: true);
    return res;
  }

  /// Sube la foto de la moto y refresca el perfil.
  Future<Result<void>> subirFotoMoto(MultipartFile archivo) async {
    final res = await _service.subirFotoMoto(archivo);
    if (res.isSuccess) await cargar(forzar: true);
    return res;
  }

  /// Demanda reciente por zonas. No se cachea: el sentido del dato es que
  /// esté fresco cada vez que el conductor mira dónde ubicarse.
  Future<Result<DemandaZonas>> demanda() => _service.demanda();

  Future<Result<Conductor>> cambiarEnLinea(bool enLinea, {LatLng? ubicacion}) async {
    final res = await _service.cambiarEnLinea(enLinea, ubicacion: ubicacion);
    _guardarSiOk(res);
    return res;
  }

  /// Reporte de ubicación (best-effort; no altera el perfil en caché).
  Future<void> reportarUbicacion(LatLng ubicacion) async {
    await _service.actualizarUbicacion(ubicacion);
  }

  void limpiar() {
    _conductor = null;
    notifyListeners();
  }

  void _guardarSiOk(Result<Conductor> res) {
    if (res case Ok<Conductor>(value: final c)) {
      _conductor = c;
      notifyListeners();
    }
  }
}

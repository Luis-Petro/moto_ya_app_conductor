import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../domain/models/conductor.dart';

/// Estado del alta del perfil de conductor.
class AltaConductorViewModel extends ChangeNotifier {
  AltaConductorViewModel(this._conductores);

  final ConductorRepository _conductores;

  bool cargando = true;
  bool guardando = false;
  bool subiendoDocumento = false;
  String? error;

  Conductor? get conductor => _conductores.conductor;
  bool get perfilCompleto => _conductores.perfilCompleto;

  /// Resuelve el perfil actual al abrir la pantalla (para saltar el alta si ya
  /// está completo).
  Future<void> cargar() async {
    cargando = true;
    notifyListeners();
    await _conductores.cargar(forzar: true);
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
        licencia: licencia, vehiculo: vehiculo, placa: placa);
    guardando = false;
    final ok = res.isSuccess;
    if (!ok) error = res.when(ok: (_) => null, err: (f) => f.message);
    notifyListeners();
    return ok;
  }

  Future<bool> subirDocumento(File archivo, {String? tipo}) async {
    subiendoDocumento = true;
    notifyListeners();
    final multipart = await MultipartFile.fromFile(archivo.path);
    final res = await _conductores.subirDocumento(multipart, tipo: tipo);
    subiendoDocumento = false;
    final ok = res.isSuccess;
    if (!ok) error = res.when(ok: (_) => null, err: (f) => f.message);
    notifyListeners();
    return ok;
  }
}

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/conductor.dart';
import '../models/api_mappers.dart';
import 'api_client.dart';
import 'api_result.dart';

/// Cliente de los endpoints del conductor (`/conductores/*`).
class ConductorService {
  ConductorService(this._api);

  final ApiClient _api;

  /// Perfil del conductor autenticado.
  Future<Result<Conductor>> obtenerPerfil() {
    return _api.get<Conductor>('/conductores/me', parse: ApiMappers.conductor);
  }

  /// Alta del perfil de conductor. El backend exige `lat`/`lng` (ubicación
  /// inicial): sin ellas el conductor quedaría en (0,0) y el matching por
  /// cercanía nunca lo encontraría.
  Future<Result<Conductor>> crearPerfil({
    required String licencia,
    required String vehiculo,
    required String placa,
    required LatLng ubicacion,
  }) {
    return _api.post<Conductor>(
      '/conductores',
      body: {
        'licencia': licencia,
        'vehiculo': vehiculo,
        'placa': placa,
        'lat': ubicacion.latitude,
        'lng': ubicacion.longitude,
      },
      parse: ApiMappers.conductor,
    );
  }

  /// Alterna el estado en línea (opcionalmente reporta la ubicación actual).
  Future<Result<Conductor>> cambiarEnLinea(bool enLinea, {LatLng? ubicacion}) {
    return _api.patch<Conductor>(
      '/conductores/me/en-linea',
      body: {
        'enLinea': enLinea,
        if (ubicacion != null) 'lat': ubicacion.latitude,
        if (ubicacion != null) 'lng': ubicacion.longitude,
      },
      parse: ApiMappers.conductor,
    );
  }

  /// Reporta la ubicación del conductor (mientras está en línea / pedido activo).
  Future<Result<void>> actualizarUbicacion(LatLng ubicacion) {
    return _api.put<void>(
      '/conductores/me/ubicacion',
      body: {'lat': ubicacion.latitude, 'lng': ubicacion.longitude},
    );
  }

  /// Sube un documento a R2. El backend espera el campo multipart `file` y
  /// devuelve `{url}` (no el perfil), por eso no se parsea como Conductor.
  Future<Result<void>> subirDocumento(MultipartFile archivo) {
    return _api.postMultipart<void>(
      '/conductores/me/documentos',
      fields: {'file': archivo},
    );
  }

  /// Sube la foto de perfil a R2 (campo multipart `file`, respuesta `{url}`).
  Future<Result<void>> subirFoto(MultipartFile archivo) {
    return _api.postMultipart<void>(
      '/conductores/me/foto',
      fields: {'file': archivo},
    );
  }

  /// Sube la cédula (obligatoria para que el admin habilite la cuenta).
  Future<Result<void>> subirCedula(MultipartFile archivo) {
    return _api.postMultipart<void>(
      '/conductores/me/cedula',
      fields: {'file': archivo},
    );
  }

  /// Sube los papeles de la moto (opcionales).
  Future<Result<void>> subirPapelesMoto(MultipartFile archivo) {
    return _api.postMultipart<void>(
      '/conductores/me/papeles-moto',
      fields: {'file': archivo},
    );
  }
}

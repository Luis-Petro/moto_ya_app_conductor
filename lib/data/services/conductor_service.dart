import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/conductor.dart';
import '../../domain/models/demanda_zonas.dart';
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
  /// cercanía nunca lo encontraría. La licencia es opcional por ahora.
  Future<Result<Conductor>> crearPerfil({
    String? licencia,
    required String vehiculo,
    required String placa,
    required LatLng ubicacion,
  }) {
    return _api.post<Conductor>(
      '/conductores',
      body: {
        if (licencia != null) 'licencia': licencia,
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

  /// Sube la tarjeta de propiedad de la moto (el endpoint conserva el nombre
  /// `papeles-moto` por compatibilidad).
  Future<Result<void>> subirPapelesMoto(MultipartFile archivo) {
    return _api.postMultipart<void>(
      '/conductores/me/papeles-moto',
      fields: {'file': archivo},
    );
  }

  /// Sube la selfie de verificación (una de las cuatro fotos que el admin
  /// necesita para habilitar la cuenta).
  Future<Result<void>> subirSelfie(MultipartFile archivo) {
    return _api.postMultipart<void>(
      '/conductores/me/selfie',
      fields: {'file': archivo},
    );
  }

  /// Sube la foto de la moto con la placa visible.
  Future<Result<void>> subirFotoMoto(MultipartFile archivo) {
    return _api.postMultipart<void>(
      '/conductores/me/foto-moto',
      fields: {'file': archivo},
    );
  }

  /// Demanda reciente por zonas del ámbito del conductor. Puede venir con
  /// `celdas` vacía: significa "no hay datos suficientes", no un error.
  Future<Result<DemandaZonas>> demanda() {
    return _api.get<DemandaZonas>('/matching/demanda',
        parse: ApiMappers.demandaZonas);
  }
}

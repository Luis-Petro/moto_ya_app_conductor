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

  /// Alta del perfil de conductor.
  Future<Result<Conductor>> crearPerfil({
    required String licencia,
    required String vehiculo,
    required String placa,
  }) {
    return _api.post<Conductor>(
      '/conductores',
      body: {'licencia': licencia, 'vehiculo': vehiculo, 'placa': placa},
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

  /// Sube un documento (licencia/vehículo) a R2 vía multipart.
  Future<Result<Conductor>> subirDocumento(MultipartFile archivo, {String? tipo}) {
    return _api.postMultipart<Conductor>(
      '/conductores/me/documentos',
      fields: {'archivo': archivo, if (tipo != null) 'tipo': tipo},
      parse: ApiMappers.conductor,
    );
  }
}

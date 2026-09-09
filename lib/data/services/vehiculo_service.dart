import '../../domain/models/catalogo_vehiculos.dart';
import '../models/api_mappers.dart';
import 'api_client.dart';
import 'api_result.dart';

/// Cliente de `/vehiculos/catalogo`: el árbol de tipos, marcas y modelos que
/// administra el panel.
///
/// **Una sola petición y no tres encadenadas.** El árbol entero son decenas de
/// filas y unos kilobytes; tres viajes en el paso del vehículo son tres
/// oportunidades de fallar en el sitio donde una persona está intentando empezar
/// a trabajar.
class VehiculoService {
  VehiculoService(this._api);

  final ApiClient _api;

  Future<Result<CatalogoVehiculos>> catalogo() {
    return _api.get<CatalogoVehiculos>(
      '/vehiculos/catalogo',
      parse: ApiMappers.catalogoVehiculos,
    );
  }
}

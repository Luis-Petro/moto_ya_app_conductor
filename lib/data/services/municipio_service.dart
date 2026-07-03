import '../../domain/models/municipio.dart';
import '../models/api_mappers.dart';
import 'api_client.dart';
import 'api_result.dart';

/// Cliente de `/municipios` (municipios activos donde opera la plataforma).
class MunicipioService {
  MunicipioService(this._api);

  final ApiClient _api;

  Future<Result<List<Municipio>>> disponibles() {
    return _api.get<List<Municipio>>(
      '/municipios',
      parse: (data) =>
          (data as List).map(ApiMappers.municipio).toList(growable: false),
    );
  }
}

import '../../domain/models/lugar.dart';
import '../models/api_mappers.dart';
import 'api_client.dart';
import 'api_result.dart';

/// Cliente de `/lugares`: catálogo de puntos de interés del municipio.
///
/// El conductor no solo consulta: **aporta**. Cada entrega es un punto que él
/// ya verificó en la calle, y ese es el motor real del catálogo en municipios
/// donde OpenStreetMap está prácticamente vacío de comercio.
class LugarService {
  LugarService(this._api);

  final ApiClient _api;

  Future<Result<List<Lugar>>> buscar({
    required int municipioId,
    String? q,
    int? limit,
  }) {
    return _api.get<List<Lugar>>(
      '/lugares',
      query: {
        'municipioId': municipioId,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (limit != null) 'limit': limit,
      },
      parse: (data) =>
          (data as List).map(ApiMappers.lugar).toList(growable: false),
    );
  }

  /// Propone un lugar nuevo. Queda pendiente de revisión del administrador
  /// antes de aparecerle a los clientes.
  Future<Result<Lugar>> proponer({
    required String nombre,
    required CategoriaLugar categoria,
    required double lat,
    required double lng,
    String? referencia,
    int? municipioId,
  }) {
    return _api.post<Lugar>(
      '/lugares/propuestos',
      body: {
        'nombre': nombre,
        'categoria': categoria.name.toUpperCase(),
        'lat': lat,
        'lng': lng,
        if (referencia != null && referencia.trim().isNotEmpty)
          'referencia': referencia.trim(),
        if (municipioId != null) 'municipioId': municipioId,
      },
      parse: ApiMappers.lugar,
    );
  }
}

import '../../domain/models/municipio.dart';
import '../services/api_result.dart';
import '../services/municipio_service.dart';

/// Catálogo de municipios disponibles, con caché en memoria (cambia poco).
class MunicipioRepository {
  MunicipioRepository(this._service);

  final MunicipioService _service;
  List<Municipio>? _cache;

  Future<Result<List<Municipio>>> disponibles({bool forzar = false}) async {
    if (_cache != null && !forzar) return Ok(_cache!);
    final res = await _service.disponibles();
    if (res case Ok<List<Municipio>>(value: final lista)) {
      _cache = lista;
    }
    return res;
  }

  /// Resuelve un municipio por id desde la caché (null si no está cargada).
  Municipio? porId(int? id) {
    if (id == null || _cache == null) return null;
    for (final m in _cache!) {
      if (m.id == id) return m;
    }
    return null;
  }

  void limpiar() => _cache = null;
}

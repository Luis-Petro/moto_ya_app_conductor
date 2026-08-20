import '../../domain/models/banner_app.dart';
import 'api_client.dart';

/// Cliente de `/banners`: los avisos que el panel publica para esta app.
///
/// El servidor ya filtra por app, por vigencia y por municipio, así que aquí no
/// se decide nada: se pinta lo que llega, en el orden en que llega.
class BannerService {
  BannerService(this._api);

  final ApiClient _api;

  /// `CLIENTE` o `CONDUCTOR`: qué app pregunta.
  static const String _app = 'CONDUCTOR';

  /// Avisos vigentes. **Cualquier fallo se resuelve como "no hay avisos"**: la
  /// franja de banners nunca puede estorbar el uso normal de la app, igual que
  /// el aviso de versión.
  Future<List<BannerApp>> vigentes() async {
    final res = await _api.get<List<BannerApp>>(
      '/banners',
      query: const {'app': _app},
      parse: (data) => (data as List)
          .map((e) => BannerApp.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
    return res.valueOrNull ?? const <BannerApp>[];
  }
}

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

  /// Avisos vigentes, o **`null` si la consulta falló**.
  ///
  /// La distinción importa desde que la franja se refresca sola: "no hay avisos"
  /// vacía la franja y "no se pudo preguntar" tiene que dejar en pantalla lo que
  /// ya estaba. Devolviendo lista vacía en los dos casos, una app que vuelve del
  /// segundo plano sin cobertura borraba los avisos que el usuario ya estaba
  /// viendo — y en una moto, sin cobertura se está a cada rato.
  ///
  /// En ninguno de los dos casos hay error en pantalla: esta franja no puede
  /// estorbar el uso normal de la app, igual que el aviso de versión.
  Future<List<BannerApp>?> vigentes() async {
    final res = await _api.get<List<BannerApp>>(
      '/banners',
      query: const {'app': _app},
      parse: (data) => (data as List)
          .map((e) => BannerApp.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
    return res.valueOrNull;
  }
}

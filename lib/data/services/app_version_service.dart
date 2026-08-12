import 'package:package_info_plus/package_info_plus.dart';

import '../../ui/core/format/version.dart';
import 'api_client.dart';

/// Versión publicada en la tienda, declarada por el admin desde el panel.
///
/// El backend solo devuelve las versiones de tienda: los APK que el CI sube al
/// panel son para pruebas internas y no llegan aquí, así que sus notas —que
/// llevan el commit y el número de build— nunca pueden acabar en pantalla.
///
/// Los enlaces de tienda pueden venir vacíos si esa app todavía no está publicada
/// en esa plataforma. No hay enlace a APK a propósito: ver `banner_version.dart`.
class VersionVigente {
  const VersionVigente({
    required this.version,
    this.notas,
    this.playStoreUrl,
    this.appStoreUrl,
  });

  final String version;

  /// Novedades escritas por el admin **para los usuarios**.
  final String? notas;
  final String? playStoreUrl;
  final String? appStoreUrl;
}

/// Compara la versión instalada con la vigente en el backend.
///
/// Todo fallo (backend caído, 204 sin releases, versión ilegible) se resuelve
/// como "no hay nada que avisar": el banner nunca puede estorbar el uso normal.
class AppVersionService {
  AppVersionService(this._api);

  final ApiClient _api;

  /// `CLIENTE` o `CONDUCTOR`: qué app pregunta.
  static const String _app = 'CONDUCTOR';

  /// Devuelve la release vigente solo si es **mayor** que la instalada.
  Future<VersionVigente?> nuevaVersionDisponible() async {
    final res = await _api.get<Map<String, dynamic>?>(
      '/app/version',
      query: {'app': _app},
      parse: (data) => data is Map ? Map<String, dynamic>.from(data) : null,
    );
    final data = res.valueOrNull;
    if (data == null) return null; // 204 sin releases o error
    final remota = data['version'] as String?;
    if (remota == null || remota.isEmpty) return null;

    final instalada = (await PackageInfo.fromPlatform()).version;
    if (compararVersiones(instalada, remota) >= 0) return null;

    return VersionVigente(
      version: remota,
      notas: data['notas'] as String?,
      playStoreUrl: data['playStoreUrl'] as String?,
      appStoreUrl: data['appStoreUrl'] as String?,
    );
  }
}

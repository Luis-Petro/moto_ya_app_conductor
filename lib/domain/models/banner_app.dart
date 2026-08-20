/// Aviso de imagen publicado desde el panel, tal como lo recibe la app.
///
/// Solo trae lo que se pinta. El título interno, la vigencia, el municipio y el
/// estado son datos de gestión y **no viajan**: el aviso que se está preparando
/// para dentro de dos semanas no tiene por qué ser deducible desde un teléfono.
class BannerApp {
  const BannerApp({
    required this.id,
    required this.imagenUrl,
    required this.textoAlternativo,
    required this.descartable,
    this.enlaceUrl,
  });

  final int id;
  final String imagenUrl;

  /// Qué dice la imagen. Lo lee el lector de pantalla.
  final String textoAlternativo;

  /// Si el usuario puede cerrarlo. Lo decide quien lo publica.
  final bool descartable;

  /// Adónde lleva el toque, o `null` si el aviso es solo informativo.
  final String? enlaceUrl;

  static BannerApp fromJson(Map<String, dynamic> json) {
    return BannerApp(
      id: (json['id'] as num).toInt(),
      imagenUrl: json['imagenUrl'] as String,
      textoAlternativo: (json['textoAlternativo'] as String?) ?? '',
      descartable: json['descartable'] as bool? ?? true,
      enlaceUrl: json['enlaceUrl'] as String?,
    );
  }
}

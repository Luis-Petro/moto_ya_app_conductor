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
    this.publicadoEn,
  });

  final int id;
  final String imagenUrl;

  /// Qué dice la imagen. Lo lee el lector de pantalla.
  final String textoAlternativo;

  /// Si el usuario puede cerrarlo. Lo decide quien lo publica.
  final bool descartable;

  /// Adónde lleva el toque, o `null` si el aviso es solo informativo.
  final String? enlaceUrl;

  /// Cuándo se publicó por última vez (cada vez que el administrador lo enciende).
  ///
  /// No es un dato de gestión: es lo que permite distinguir una publicación de
  /// otra. Sin él, el descarte solo podía guardarse por id y un banner apagado y
  /// vuelto a encender no reaparecía nunca en el teléfono de quien lo cerró.
  final DateTime? publicadoEn;

  /// Contra qué se guarda el descarte: el aviso **y** su publicación.
  ///
  /// `null` cuando el servidor no manda el instante —una versión anterior del
  /// backend—: en ese caso el aviso nunca se considera descartado. Entre enseñar
  /// un aviso de más y ocultar para siempre uno que el administrador acaba de
  /// publicar, lo primero.
  String? get claveDescarte {
    final publicado = publicadoEn;
    return publicado == null ? null : '$id:${publicado.millisecondsSinceEpoch}';
  }

  static BannerApp fromJson(Map<String, dynamic> json) {
    return BannerApp(
      id: (json['id'] as num).toInt(),
      imagenUrl: json['imagenUrl'] as String,
      textoAlternativo: (json['textoAlternativo'] as String?) ?? '',
      descartable: json['descartable'] as bool? ?? true,
      enlaceUrl: json['enlaceUrl'] as String?,
      publicadoEn: DateTime.tryParse((json['publicadoEn'] as String?) ?? ''),
    );
  }
}

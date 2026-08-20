import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Qué avisos cerró el usuario en **este** dispositivo.
///
/// Un banner descartable que reaparece en cada apertura deja de ser un aviso y
/// pasa a ser una molestia, y la salida del usuario no es cerrarlo otra vez: es
/// dejar de mirar esa franja. En la app del conductor eso es más caro todavía,
/// porque en esa misma franja aparecen los avisos de su cuenta.
///
/// **El descarte se guarda contra el aviso Y su publicación** (`<id>:<millis>`),
/// no contra el id a secas. Con el id, apagar y encender un banner desde el
/// panel no lo resucitaba en el teléfono de quien lo había cerrado, y como esto
/// vive en `flutter_secure_storage` —o sea en los datos de la app, no en la
/// caché— la única salida que le quedaba al usuario era cerrar sesión o borrar
/// los datos. Eso no es arreglarlo: es pasarle el problema a él.
///
/// Se guarda en `flutter_secure_storage` —no porque sea un secreto, sino porque
/// es el almacenamiento clave-valor que la app ya tiene registrado— y se borra
/// al cerrar sesión con el resto del estado de la sesión.
class BannerDescartes {
  BannerDescartes([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _clave = 'banners_descartados';

  final FlutterSecureStorage _storage;
  Set<String>? _cache;

  /// Las claves `<id>:<millis>` guardadas.
  ///
  /// Las entradas **sin** `:` son de una versión anterior, que guardaba solo el
  /// id, y se ignoran: no dicen a qué publicación se referían. Esto hace que
  /// tras actualizar la app cada usuario vea una vez los avisos que había
  /// cerrado, y es el lado correcto por el que equivocarse — el otro es dejar
  /// oculto para siempre un aviso que el administrador acaba de publicar.
  Future<Set<String>> descartados() async {
    final cacheado = _cache;
    if (cacheado != null) return cacheado;
    final raw = await _storage.read(key: _clave);
    final claves = <String>{};
    for (final parte in (raw ?? '').split(',')) {
      final limpia = parte.trim();
      if (limpia.contains(':')) claves.add(limpia);
    }
    _cache = claves;
    return claves;
  }

  /// Guarda un descarte y **depura** los que ya no vienen del servidor.
  ///
  /// [idsVigentes] son los ids de la última respuesta de `/banners`. Sin esta
  /// poda la lista crece para siempre con ids de banners borrados hace meses,
  /// que no vuelven a consultarse nunca y no hay forma de limpiar.
  ///
  /// Consecuencia aceptada: el descarte de un banner temporalmente desactivado
  /// se olvida, porque no está en la respuesta. Si se vuelve a activar,
  /// reaparece — que es justo lo que se busca.
  Future<void> descartar(String clave, {Set<int> idsVigentes = const {}}) async {
    final previas = await descartados();
    final claves = <String>{
      for (final c in previas)
        if (idsVigentes.contains(int.tryParse(c.split(':').first))) c,
      clave,
    };
    _cache = claves;
    await _storage.write(key: _clave, value: claves.join(','));
  }

  /// Al cerrar sesión: el teléfono puede pasar a otra persona.
  Future<void> borrar() async {
    _cache = null;
    await _storage.delete(key: _clave);
  }
}

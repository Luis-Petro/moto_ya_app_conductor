import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Qué avisos cerró el usuario en **este** dispositivo.
///
/// Un banner descartable que reaparece en cada apertura deja de ser un aviso y
/// pasa a ser una molestia, y la salida del usuario no es cerrarlo otra vez: es
/// dejar de mirar esa franja. En la app del conductor eso es más caro todavía,
/// porque en esa misma franja aparecen los avisos de su cuenta.
///
/// Se guarda en `flutter_secure_storage` —no porque sea un secreto, sino porque
/// es el almacenamiento clave-valor que la app ya tiene registrado— y se borra
/// al cerrar sesión con el resto del estado de la sesión.
///
/// Los identificadores no se reutilizan: si el administrador borra un banner y
/// sube otro, es un aviso distinto y vuelve a aparecer. Correcto, no un fallo.
class BannerDescartes {
  BannerDescartes([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _clave = 'banners_descartados';

  final FlutterSecureStorage _storage;
  Set<int>? _cache;

  Future<Set<int>> descartados() async {
    final cacheado = _cache;
    if (cacheado != null) return cacheado;
    final raw = await _storage.read(key: _clave);
    final ids = <int>{};
    for (final parte in (raw ?? '').split(',')) {
      final id = int.tryParse(parte.trim());
      if (id != null) ids.add(id);
    }
    _cache = ids;
    return ids;
  }

  Future<void> descartar(int id) async {
    final ids = {...await descartados(), id};
    _cache = ids;
    await _storage.write(key: _clave, value: ids.join(','));
  }

  /// Al cerrar sesión: el teléfono puede pasar a otra persona.
  Future<void> borrar() async {
    _cache = null;
    await _storage.delete(key: _clave);
  }
}

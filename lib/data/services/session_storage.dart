import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/sesion.dart';

/// Almacenamiento seguro de la sesión (JWT + identidad). Usa Keychain/Encrypted
/// SharedPreferences vía `flutter_secure_storage` — nunca almacenamiento plano
/// (anti-patrón de seguridad móvil).
class SessionStorage {
  SessionStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kSesion = 'sesion';
  final FlutterSecureStorage _storage;

  Sesion? _cache;

  Future<Sesion?> leer() async {
    if (_cache != null) return _cache;
    final raw = await _storage.read(key: _kSesion);
    if (raw == null) return null;
    try {
      _cache = Sesion.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _cache;
    } catch (_) {
      await borrar();
      return null;
    }
  }

  Future<void> guardar(Sesion sesion) async {
    _cache = sesion;
    await _storage.write(key: _kSesion, value: jsonEncode(sesion.toJson()));
  }

  Future<void> borrar() async {
    _cache = null;
    await _storage.delete(key: _kSesion);
  }
}

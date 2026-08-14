import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Identidad del teléfono, para el panel y para el reporte de feedback.
///
/// Dos datos, los dos obtenidos y nunca preguntados:
///
/// - **Un identificador de la instalación**: un UUID propio que se genera la
///   primera vez y se guarda en el almacenamiento seguro. No se usa el
///   `androidId` ni el `identifierForVendor` — Play trata los identificadores de
///   hardware persistentes como dato sensible y obliga a declararlos y
///   justificarlos, y no responden mejor la única pregunta que se hace aquí
///   ("¿es el mismo teléfono de siempre?"). El UUID propio se borra al
///   desinstalar, que es el comportamiento honesto: quien reinstala es un
///   equipo nuevo y así se muestra.
/// - **Una descripción legible**: "Xiaomi Redmi Note 12 · Android 13 · app 1.0.0".
///   Es lo que hace reproducible un reporte de fallo; pedírsela al usuario es la
///   fricción que hace que no reporte.
///
/// Ambos se resuelven **una sola vez** y se cachean: van en cada petición, y
/// consultar el sistema en cada una sería gasto por nada.
class DispositivoService {
  DispositivoService([FlutterSecureStorage? storage, DeviceInfoPlugin? info])
      : _storage = storage ?? const FlutterSecureStorage(),
        _info = info ?? DeviceInfoPlugin();

  static const _kId = 'dispositivo_id';

  /// Tope de la descripción: el servidor recorta a 120 y no tiene sentido
  /// mandar más de lo que se va a guardar.
  static const int maxDescripcion = 120;

  final FlutterSecureStorage _storage;
  final DeviceInfoPlugin _info;

  String? _id;
  String? _descripcion;

  /// Identificador de esta instalación. Estable entre arranques.
  Future<String> id() async {
    if (_id != null) return _id!;
    final guardado = await _storage.read(key: _kId);
    if (guardado != null && guardado.isNotEmpty) {
      _id = guardado;
      return guardado;
    }
    final nuevo = _generarId();
    await _storage.write(key: _kId, value: nuevo);
    _id = nuevo;
    return nuevo;
  }

  /// "Xiaomi Redmi Note 12 · Android 13 · app 1.0.0".
  ///
  /// Si el sistema no responde, se devuelve lo que se sepa. Un fallo aquí no
  /// puede impedir una petición: esto es contexto de soporte, no una credencial.
  Future<String> descripcion() async {
    if (_descripcion != null) return _descripcion!;
    final partes = <String>[];
    try {
      if (Platform.isAndroid) {
        final a = await _info.androidInfo;
        partes.add('${a.manufacturer} ${a.model}'.trim());
        partes.add('Android ${a.version.release}');
      } else if (Platform.isIOS) {
        final i = await _info.iosInfo;
        partes.add(i.utsname.machine);
        partes.add('${i.systemName} ${i.systemVersion}');
      }
    } catch (e) {
      debugPrint('DispositivoService: no se pudo leer el equipo ($e)');
    }
    try {
      final paquete = await PackageInfo.fromPlatform();
      partes.add('app ${paquete.version}');
    } catch (e) {
      debugPrint('DispositivoService: no se pudo leer la versión ($e)');
    }
    final texto = partes.where((p) => p.trim().isNotEmpty).join(' · ');
    _descripcion = texto.length <= maxDescripcion
        ? texto
        : texto.substring(0, maxDescripcion);
    return _descripcion!;
  }

  /// UUID v4 con el generador seguro de la plataforma. Se compone a mano para
  /// no añadir un paquete entero por dieciséis bytes.
  String _generarId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

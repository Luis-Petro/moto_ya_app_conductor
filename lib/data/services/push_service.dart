import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../config/env.dart';

/// Notificación de negocio normalizada para navegación interna.
class PushMensaje {
  const PushMensaje({
    this.titulo,
    this.cuerpo,
    this.pedidoId,
    this.tipo,
    this.vigencia,
  });
  final String? titulo;
  final String? cuerpo;
  final int? pedidoId;

  /// Tipo de evento de negocio: PROPUESTA, ACEPTACION, PEDIDO_NUEVO, etc.
  final String? tipo;

  /// Cuánto le queda de vida a la oferta. Solo viene en `PEDIDO_NUEVO`.
  final Duration? vigencia;

  /// El único aviso que la app pinta por su cuenta, porque es el único que va a
  /// pantalla completa.
  static const tipoOferta = 'PEDIDO_NUEVO';

  static PushMensaje fromRemote(RemoteMessage m) {
    final data = m.data;
    final pedidoRaw = data['pedidoId'] ?? data['pedido_id'];
    final segundos = int.tryParse('${data['segundosRestantes']}');
    return PushMensaje(
      // La oferta viaja como mensaje de datos y no trae bloque de notificación,
      // así que su título y su cuerpo vienen en los datos. El resto de avisos sí
      // lo traen. Se lee de los dos sitios para no tener dos rutas de lectura.
      titulo: m.notification?.title ?? data['titulo'] as String?,
      cuerpo: m.notification?.body ?? data['cuerpo'] as String?,
      pedidoId: pedidoRaw == null ? null : int.tryParse(pedidoRaw.toString()),
      tipo: data['tipo'] as String?,
      vigencia: segundos == null || segundos <= 0
          ? null
          : Duration(seconds: segundos),
    );
  }
}

/// Handler de mensajes en background (debe ser top-level).
///
/// **No pinta nada, a propósito.** Todos los avisos —la oferta incluida— llevan
/// bloque de notificación, así que los publica el SDK de FCM sobre el canal que
/// declara el backend, sin ejecutar una línea nuestra.
///
/// La oferta se mandó un tiempo como mensaje solo de datos para poder construir
/// aquí el aviso a pantalla completa. Salió mal: un mensaje de datos necesita que
/// **este isolate despierte**, y en los teléfonos de gama media que son el parque
/// real muchas veces no despierta — ni notificación, ni sonido, ni error. Sonar
/// siempre vale más que sonar a pantalla completa a veces.
///
/// La pantalla completa se conserva por el otro camino: con la app viva, la
/// oferta llega además por STOMP o por el sondeo y ahí sí la construye el Inicio.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // Sin lógica: el sistema ya mostró la notificación. El toque se atiende al
  // reabrir la app vía getInitialMessage / onMessageOpenedApp.
}

/// Integración con Firebase Cloud Messaging. Es defensiva: si FCM no está
/// habilitado/configurado (`Env.fcmEnabled`), todos los métodos son no-op para
/// no romper el arranque en entornos sin `google-services.json`.
class PushService {
  bool get _activo => Env.fcmEnabled && !kIsWeb;

  void Function(PushMensaje)? onMensajeForeground;
  void Function(PushMensaje)? onMensajeAbierto;

  Future<void> inicializar() async {
    if (!_activo) return;
    try {
      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onMessage.listen((m) {
        onMensajeForeground?.call(PushMensaje.fromRemote(m));
      });
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        onMensajeAbierto?.call(PushMensaje.fromRemote(m));
      });
      final inicial = await FirebaseMessaging.instance.getInitialMessage();
      if (inicial != null) {
        onMensajeAbierto?.call(PushMensaje.fromRemote(inicial));
      }
    } catch (_) {/* FCM no configurado: ignorar */}
  }

  Future<String?> obtenerToken() async {
    if (!_activo) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Verifica el permiso de notificaciones y, si aún no está concedido, lo
  /// solicita (dispara el prompt del SO en Android 13+ / iOS). Devuelve `true`
  /// si quedó autorizado. Si FCM no está activo (o no está configurado)
  /// devuelve `true` para no bloquear al conductor por infra que no tenemos:
  /// el canal STOMP + sondeo de ofertas siguen funcionando sin push.
  Future<bool> asegurarPermiso() async {
    if (!_activo) return true;
    try {
      var s = await FirebaseMessaging.instance.getNotificationSettings();
      if (_autorizado(s.authorizationStatus)) return true;
      s = await FirebaseMessaging.instance.requestPermission();
      return _autorizado(s.authorizationStatus);
    } catch (_) {
      return true; // FCM no configurado: no bloquear
    }
  }

  bool _autorizado(AuthorizationStatus st) =>
      st == AuthorizationStatus.authorized ||
      st == AuthorizationStatus.provisional;

  String get plataforma => Platform.isIOS ? 'IOS' : 'ANDROID';
}

import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../config/env.dart';

/// Notificación de negocio normalizada para navegación interna.
class PushMensaje {
  const PushMensaje({this.titulo, this.cuerpo, this.pedidoId, this.tipo});
  final String? titulo;
  final String? cuerpo;
  final int? pedidoId;

  /// Tipo de evento de negocio: PROPUESTA, ACEPTACION, PEDIDO_NUEVO, etc.
  final String? tipo;

  static PushMensaje fromRemote(RemoteMessage m) {
    final data = m.data;
    final pedidoRaw = data['pedidoId'] ?? data['pedido_id'];
    return PushMensaje(
      titulo: m.notification?.title,
      cuerpo: m.notification?.body,
      pedidoId: pedidoRaw == null ? null : int.tryParse(pedidoRaw.toString()),
      tipo: data['tipo'] as String?,
    );
  }
}

/// Handler de mensajes en background (debe ser top-level).
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // Sin lógica pesada: el sistema muestra la notificación; el tap se maneja
  // al reabrir la app vía getInitialMessage / onMessageOpenedApp.
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

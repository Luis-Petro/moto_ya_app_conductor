import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../config/env.dart';
import 'notificacion_local_service.dart';

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
/// Corre en un isolate propio, sin la app ni la DI montadas, así que solo puede
/// depender de lo que construya él mismo.
///
/// Para todo lo que no sea una oferta no hace nada: el mensaje trae bloque de
/// notificación y la pinta el sistema. La **oferta** llega como mensaje de datos
/// —una notificación a pantalla completa no se puede pedir desde el payload de
/// FCM— y es aquí donde se construye. Y solo aquí: con la app en primer plano el
/// mensaje entra por `onMessage` y la oferta se presenta dentro de la app, así
/// que este camino no puede duplicarla.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  final aviso = PushMensaje.fromRemote(message);
  if (aviso.tipo != PushMensaje.tipoOferta || aviso.pedidoId == null) return;
  await NotificacionLocalService().mostrarOferta(
    pedidoId: aviso.pedidoId!,
    titulo: aviso.titulo ?? '¡Nuevo pedido!',
    cuerpo: aviso.cuerpo ?? 'Tienes un pedido cercano.',
    vigencia: aviso.vigencia,
  );
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

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Ids de los canales de notificación de la app conductor.
///
/// Tienen que coincidir carácter por carácter con `ZumbeoApplication.kt` (que es
/// quien los crea, al arrancar el proceso) y con `PushNotificationService` del
/// backend. Un id que no existe entrega la notificación muda y sin ningún error.
class CanalesNotificacion {
  const CanalesNotificacion._();

  /// Ofertas de pedido. Suena con el tono propio (`res/raw/notisound.ogg`) por el
  /// flujo de audio de **timbre**, no por el de notificación: un conductor en
  /// moto y con casco no oye el segundo.
  ///
  /// `_v2` porque el tono cambió. Un canal congela su sonido en la primera
  /// creación, así que el tono nuevo solo llega con un id nuevo.
  static const oferta = 'motoya_oferta_v2';

  /// El resto de los avisos. Va aparte a propósito: con un canal único, silenciar
  /// los avisos generales silenciaría también los pedidos.
  static const avisos = 'motoya_avisos_v1';
}

/// Construye en el dispositivo el aviso de una oferta entrante.
///
/// Existe porque una notificación a pantalla completa (`fullScreenIntent` +
/// categoría llamada) **no se puede pedir desde el payload de FCM**: el backend
/// manda la oferta como mensaje de datos y aquí se pinta. Con el teléfono en el
/// bolsillo y la pantalla bloqueada es lo único que hace que el conductor se
/// entere dentro de la ventana de respuesta.
class NotificacionLocalService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _listo = false;

  bool get _soportado => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Toque sobre el aviso de una oferta. Lo pone la app para llevar al conductor
  /// a la tarjeta del pedido. Sin esto, el aviso despierta la pantalla y deja al
  /// conductor en el Inicio buscando qué pedido era, con el reloj corriendo.
  ///
  /// No lo cubre `onMessageOpenedApp` de FCM: ese solo dispara con notificaciones
  /// que pinta el sistema, y esta la pinta la app.
  void Function(int pedidoId)? onOfertaTocada;

  /// Idempotente y tolerante a fallos: si el plugin no arranca, la app sigue —
  /// con la app abierta la oferta se presenta por su camino de siempre (STOMP y
  /// sondeo), y este servicio solo cubre el caso de la app cerrada.
  Future<void> inicializar() async {
    if (_listo || !_soportado) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // El permiso ya lo pide FCM; aquí solo se declara la presentación.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _alTocar,
      );
      _listo = true;
    } catch (_) {
      // Sin canal de aviso local, pero sin romper el arranque.
    }
  }

  /// Si la app se abrió **desde** el aviso, el toque ya ocurrió antes de que
  /// hubiera nadie escuchando. Se consulta una vez al arrancar.
  Future<void> atenderAperturaDesdeAviso() async {
    if (!_soportado) return;
    try {
      final lanzamiento = await _plugin.getNotificationAppLaunchDetails();
      if (lanzamiento?.didNotificationLaunchApp ?? false) {
        _alTocar(lanzamiento!.notificationResponse);
      }
    } catch (_) {/* nada que atender */}
  }

  void _alTocar(NotificationResponse? respuesta) {
    final pedidoId = int.tryParse(respuesta?.payload ?? '');
    if (pedidoId != null) onOfertaTocada?.call(pedidoId);
  }

  /// Pide el permiso de pantalla completa de Android 14+.
  ///
  /// Desde Android 14 `USE_FULL_SCREEN_INTENT` solo se concede de oficio a las
  /// apps de llamadas y alarmas; al resto hay que pedírselo al usuario. Si lo
  /// niega, el aviso **no desaparece**: sale como heads-up normal por el canal de
  /// ofertas, que ya suena con el volumen de timbre. Por eso no bloquea nada.
  Future<void> pedirPermisoPantallaCompleta() async {
    if (!_soportado || !Platform.isAndroid) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestFullScreenIntentPermission();
    } catch (_) {/* la versión de Android no lo expone */}
  }

  /// Muestra el aviso de una oferta. [vigencia] la retira sola al agotarse.
  ///
  /// Ese vencimiento automático no es un adorno: con la app cerrada no llega
  /// ningún evento de cierre (los de "venció" y "ya lo tomó otro" viajan por
  /// STOMP, que necesita la app viva), así que sin él el aviso se quedaría en la
  /// bandeja ofreciendo un pedido que ya no existe.
  Future<void> mostrarOferta({
    required int pedidoId,
    required String titulo,
    required String cuerpo,
    Duration? vigencia,
  }) async {
    await inicializar();
    if (!_listo) return;
    final android = AndroidNotificationDetails(
      CanalesNotificacion.oferta,
      'Pedidos entrantes',
      channelDescription:
          'El aviso de un pedido disponible. Suena con el volumen de llamada.',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      // Despierta la pantalla bloqueada como una llamada entrante. Sigue siendo
      // descartable: no bloquea el teléfono ni impide usar otra app.
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      ticker: titulo,
      timeoutAfter: vigencia?.inMilliseconds,
    );
    try {
      await _plugin.show(
        _idDe(pedidoId),
        titulo,
        cuerpo,
        NotificationDetails(
          android: android,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: pedidoId.toString(),
      );
    } catch (_) {/* mejor sin aviso que con la app caída */}
  }

  /// Retira el aviso de una oferta (venció, la tomó otro o el pedido se canceló).
  Future<void> retirarOferta(int pedidoId) async {
    if (!_soportado) return;
    try {
      await _plugin.cancel(_idDe(pedidoId));
    } catch (_) {/* nada que retirar */}
  }

  /// Id de notificación derivado del pedido: dos avisos del mismo pedido se
  /// reemplazan en lugar de apilarse, y retirarlo no necesita recordar nada.
  /// El módulo mantiene el id dentro del entero de 32 bits que exige Android.
  int _idDe(int pedidoId) => 1000000 + (pedidoId % 1000000);
}

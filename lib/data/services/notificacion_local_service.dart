import 'dart:async';
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
  /// **`_v4` por el patrón de vibración propio.** Un canal fija su sonido, su
  /// importancia **y su vibración** en la primera creación, y las llamadas
  /// posteriores se ignoran en silencio: cualquiera de esas tres cosas que cambie
  /// obliga a un id nuevo. `_v1` traía el tono del sistema, `_v2` quedó congelado
  /// con el de fábrica, `_v3` estrenó el tono propio.
  static const oferta = 'motoya_oferta_v4';

  /// El resto de los avisos. Va aparte a propósito: con un canal único, silenciar
  /// los avisos generales silenciaría también los pedidos.
  static const avisos = 'motoya_avisos_v1';

  /// Nombre del recurso del tono en `res/raw`, **sin extensión**, que es como lo
  /// nombra Android. Tiene que coincidir con `ZumbeoApplication.kt` y con
  /// `PushNotificationService.SONIDO_OFERTA` del backend.
  static const tonoOferta = 'notisound';
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
      await _crearCanalDeOfertas();
      _listo = true;
    } catch (e) {
      // Sin canal de aviso local, pero sin romper el arranque. Lo que NO puede
      // pasar es que se caiga en silencio: un aviso que no suena y no deja rastro
      // ya costó dos diagnósticos equivocados.
      debugPrint('NotificacionLocal: no se pudo inicializar el plugin: $e');
    }
  }

  /// Crea el canal de ofertas **con su tono**, también desde Dart.
  ///
  /// Ya lo crea `ZumbeoApplication.kt` al arrancar el proceso, y aun así hace
  /// falta aquí. El motivo es el que dejó la app sonando con el tono por defecto:
  /// **`show()` crea el canal si no existe, usando lo que traiga
  /// `AndroidNotificationDetails`** — y ahí no iba ningún sonido, así que quedaba
  /// el de fábrica. Gana el que llegue primero, y el que llegue primero congela
  /// el sonido para siempre.
  ///
  /// Con las dos vías declarando lo mismo, deja de importar cuál gane. Es la
  /// única forma de que no dependa del orden de arranque.
  Future<void> _crearCanalDeOfertas() async {
    if (!Platform.isAndroid) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            AndroidNotificationChannel(
              CanalesNotificacion.oferta,
              'Pedidos entrantes',
              description:
                  'El aviso de un pedido disponible. Suena con el volumen de llamada.',
              importance: Importance.max,
              sound: RawResourceAndroidNotificationSound(
                CanalesNotificacion.tonoOferta,
              ),
              // Por el flujo de audio de TIMBRE, no por el de notificación, que
              // en la mayoría de los teléfonos está muy por debajo.
              audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
              enableVibration: true,
              vibrationPattern: _patronVibracion,
            ),
          );
    } catch (e) {
      debugPrint('NotificacionLocal: no se pudo crear el canal de ofertas: $e');
    }
  }

  /// Estado real del aviso, leído de Android, no de lo que creemos haber hecho.
  ///
  /// Existe porque "no suena" se puede deber a media docena de cosas —permiso
  /// denegado, canal inexistente, canal creado sin sonido, canal silenciado por
  /// el usuario, teléfono en vibración— y desde fuera todas se ven igual. Esto
  /// las separa en una línea de log.
  Future<String> diagnostico() async {
    if (!Platform.isAndroid) return 'Diagnóstico solo disponible en Android.';
    await inicializar();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return 'El plugin de notificaciones no está disponible.';
    final lineas = <String>[];
    try {
      final permitido = await android.areNotificationsEnabled();
      lineas.add('Permiso de notificaciones: ${permitido == true ? 'sí' : 'NO'}');
    } catch (e) {
      lineas.add('Permiso de notificaciones: no se pudo consultar ($e)');
    }
    try {
      final canales = await android.getNotificationChannels() ?? [];
      AndroidNotificationChannel? oferta;
      for (final c in canales) {
        if (c.id == CanalesNotificacion.oferta) oferta = c;
      }
      if (oferta == null) {
        lineas.add(
          'Canal ${CanalesNotificacion.oferta}: NO EXISTE. '
          'Lo crea ZumbeoApplication al arrancar el proceso.',
        );
      } else {
        lineas
          ..add('Canal ${oferta.id}: existe')
          ..add('  importancia: ${_importancia(oferta.importance)}')
          ..add('  sonido: ${_sonido(oferta.sound)}')
          ..add('  origen del sonido: ${oferta.audioAttributesUsage.name}');
      }
      lineas.add('Canales creados: ${canales.map((c) => c.id).join(', ')}');
    } catch (e) {
      lineas.add('No se pudieron leer los canales: $e');
    }
    try {
      final permiso = await android.canScheduleExactNotifications();
      lineas.add('Avisos exactos: ${permiso == true ? 'sí' : 'no'}');
    } catch (_) {/* no todas las versiones lo exponen */}
    final texto = lineas.join('\n');
    debugPrint('NotificacionLocal · diagnóstico:\n$texto');
    return texto;
  }

  /// El sonido del canal, dicho en castellano.
  ///
  /// `AndroidNotificationSound` no tiene `toString()` propio, así que
  /// interpolarlo imprimía `Instance of 'RawResourceAndroidNotificationSound'`
  /// — texto de depuración de Dart, en la pantalla de un conductor. Y encima
  /// ocultaba el único dato que importa: **qué** tono quedó configurado.
  static String _sonido(AndroidNotificationSound? sonido) => switch (sonido) {
    null => 'NINGUNO (canal mudo)',
    RawResourceAndroidNotificationSound r => 'propio (${r.sound})',
    UriAndroidNotificationSound u => 'por URI (${u.sound})',
    _ => 'del sistema',
  };

  /// La importancia, con su nombre además del número: "4" no le dice nada a
  /// quien lee esto por teléfono, y este diagnóstico se lee por teléfono.
  static String _importancia(Importance importancia) {
    final nombre = switch (importancia.value) {
      5 => 'máxima',
      4 => 'alta',
      3 => 'media',
      2 => 'baja',
      1 => 'mínima',
      0 => 'NINGUNA (el canal no avisa)',
      _ => 'sin definir',
    };
    return '${importancia.value} ($nombre)';
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
    // El id negativo es el de la prueba de tono: no hay pedido al que llevar, y
    // navegar a uno inexistente sería peor que no hacer nada.
    if (pedidoId != null && pedidoId > 0) onOfertaTocada?.call(pedidoId);
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
  ///
  /// **Lo llama quien DETECTA la oferta, venga por donde venga**: el handler de
  /// background con la app cerrada, y el Inicio cuando la trae STOMP o el sondeo.
  /// Atarlo solo a FCM fue el error que dejó la app muda: el push depende de una
  /// credencial que nadie había comprobado, mientras que STOMP y el sondeo
  /// funcionan siempre — y por ese camino no sonaba nada.
  ///
  /// Es idempotente por pedido: si ya hay un aviso vivo para ese pedido no vuelve
  /// a sonar. La comprobación va contra las notificaciones **activas del sistema**
  /// y no contra una variable, porque el handler de background corre en otro
  /// isolate y no comparte memoria con la app.
  Future<void> mostrarOferta({
    required int pedidoId,
    required String titulo,
    required String cuerpo,
    Duration? vigencia,
  }) async {
    await inicializar();
    if (!_listo) {
      debugPrint('NotificacionLocal: aviso del pedido $pedidoId descartado, '
          'el plugin no está listo.');
      return;
    }
    if (await _yaEstaAvisado(pedidoId)) {
      debugPrint('NotificacionLocal: el pedido $pedidoId ya tiene aviso vivo.');
      return;
    }
    await _publicar(pedidoId, titulo, cuerpo, vigencia);
    _programarInsistencias(pedidoId, titulo, cuerpo, vigencia);
  }

  /// Publica el aviso. **Sin el guardado anti-duplicados**, porque las
  /// insistencias son republicaciones deliberadas del mismo aviso.
  Future<void> _publicar(
    int pedidoId,
    String titulo,
    String cuerpo,
    Duration? vigencia,
  ) async {
    final android = AndroidNotificationDetails(
      CanalesNotificacion.oferta,
      'Pedidos entrantes',
      channelDescription:
          'El aviso de un pedido disponible. Suena con el volumen de llamada.',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      // El tono va TAMBIÉN aquí, no solo en el canal. `show()` crea el canal si
      // no existe usando justo estos datos, y mientras aquí no hubo sonido, el
      // canal nacía con el de fábrica y quedaba congelado así para siempre. Fue
      // lo que hizo que llegara la notificación de llamada pero sin nuestro tono.
      sound: const RawResourceAndroidNotificationSound(
        CanalesNotificacion.tonoOferta,
      ),
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      // Para un teléfono en el bolsillo de una chaqueta, la vibración pesa más
      // que el tono. La del sistema es un pulso corto y genérico que se confunde
      // con cualquier mensaje; esta es larga y con ritmo propio.
      vibrationPattern: _patronVibracion,
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
      debugPrint('NotificacionLocal: aviso lanzado para el pedido $pedidoId '
          'en el canal ${CanalesNotificacion.oferta}.');
    } catch (e) {
      // Mejor sin aviso que con la app caída, pero nunca sin rastro.
      debugPrint('NotificacionLocal: falló el aviso del pedido $pedidoId: $e');
    }
  }

  /// Cuándo se repite el aviso de una oferta sin responder.
  ///
  /// **Se repite, no se alarga.** Un motor y el viento no bajan el volumen del
  /// tono: lo enmascaran, y si no atraviesa en los primeros segundos tampoco va a
  /// atravesar al décimo. Lo que cambia el resultado es cuántas oportunidades
  /// tiene, porque una moto no hace ruido constante — para en un semáforo, baja
  /// al reducir, se detiene en una esquina.
  ///
  /// Tres toques y no un bucle: el riesgo de un aviso insistente no es molestar,
  /// es que el conductor **silencie el canal de ofertas** en los ajustes. Ahí
  /// pierde todos los pedidos y no hay código que lo recupere.
  static const _insistencias = [Duration(seconds: 20), Duration(seconds: 40)];

  /// Vibración larga y con ritmo propio: espera, largo, corto, largo, corto,
  /// muy largo. En milisegundos, alternando silencio y vibración.
  static final _patronVibracion = Int64List.fromList(
    [0, 600, 300, 600, 300, 900],
  );

  final Map<int, List<Timer>> _insistiendo = {};

  void _programarInsistencias(
    int pedidoId,
    String titulo,
    String cuerpo,
    Duration? vigencia,
  ) {
    _cancelarInsistencias(pedidoId);
    final timers = <Timer>[];
    for (final cuando in _insistencias) {
      // Nunca después de que la oferta venza: sonar por un pedido que ya no
      // existe enseña al conductor a desconfiar del aviso, que es la única cosa
      // que no se puede permitir que aprenda.
      if (vigencia != null && cuando >= vigencia) continue;
      timers.add(
        Timer(cuando, () async {
          // Si el aviso ya no está en la bandeja, es que lo atendió o se retiró.
          if (!await _yaEstaAvisado(pedidoId)) {
            _cancelarInsistencias(pedidoId);
            return;
          }
          await _publicar(pedidoId, titulo, cuerpo, vigencia);
        }),
      );
    }
    if (timers.isNotEmpty) _insistiendo[pedidoId] = timers;
  }

  void _cancelarInsistencias(int pedidoId) {
    for (final t in _insistiendo.remove(pedidoId) ?? const <Timer>[]) {
      t.cancel();
    }
  }

  /// Lanza el **mismo aviso** que una oferta real, con datos de ejemplo.
  ///
  /// Es la única forma de comprobar el tono sin esperar a que entre un pedido. Y
  /// manda exactamente lo que manda el aviso real —mismo canal, mismo sonido,
  /// misma construcción— porque una comprobación que difiere del camino real
  /// acaba certificando el camino equivocado; eso ya costó semanas con el aviso
  /// de pago al administrador.
  ///
  /// Devuelve el diagnóstico del canal, que es lo que dice **por qué** no suena
  /// cuando no suena.
  Future<String> probarTono() async {
    final estado = await diagnostico();
    // Retira el aviso de la prueba anterior ANTES de lanzar el nuevo.
    //
    // Sin esto el botón solo suena la primera vez: el aviso sigue vivo 30
    // segundos y el guardado anti-duplicados descarta el siguiente en silencio.
    // Quien está probando un sonido aprieta tres veces seguidas, y las dos
    // últimas parecían no hacer nada — que es exactamente el síntoma que se
    // estaba intentando diagnosticar.
    await retirarOferta(_pedidoDePrueba);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await mostrarOferta(
      pedidoId: _pedidoDePrueba,
      titulo: 'Prueba de sonido',
      cuerpo: 'Así suena un pedido nuevo.',
      vigencia: const Duration(seconds: 30),
    );
    return estado;
  }

  /// Id reservado para la prueba: no puede chocar con un pedido real ni dejar al
  /// conductor con un aviso que lleva a un pedido que no existe.
  static const _pedidoDePrueba = -1;

  /// ¿Ya hay un aviso vivo para ese pedido?
  ///
  /// Ante la duda responde **que no**: perder un aviso por creerlo duplicado es
  /// mucho peor que sonar dos veces. Por eso cualquier fallo de la consulta se
  /// resuelve avisando.
  Future<bool> _yaEstaAvisado(int pedidoId) async {
    if (!Platform.isAndroid) return false;
    try {
      final activas = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.getActiveNotifications();
      if (activas == null) return false;
      // La etiqueta con la que el SDK de FCM publica el mismo aviso. Sin
      // comprobarla, un teléfono donde el push SÍ funciona recibiría dos avisos
      // del mismo pedido: el del sistema y el nuestro.
      final etiquetaFcm = 'PEDIDO_NUEVO:$pedidoId';
      return activas.any(
        (n) => n.id == _idDe(pedidoId) || n.tag == etiquetaFcm,
      );
    } catch (_) {
      // Ante la duda, avisar: perder una oferta por creerla duplicada es mucho
      // peor que sonar dos veces.
      return false;
    }
  }

  /// Retira el aviso de una oferta (venció, la tomó otro o el pedido se canceló).
  Future<void> retirarOferta(int pedidoId) async {
    // Lo primero, siempre: si la oferta se cerró, lo peor que puede pasar es que
    // el teléfono vuelva a sonar veinte segundos después por un pedido que ya
    // tomó otro.
    _cancelarInsistencias(pedidoId);
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

import 'dart:io';

import 'package:app_conductor/data/services/notificacion_local_service.dart';
import 'package:app_conductor/data/services/push_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guardas del **aviso de oferta**: lo que hace que un conductor con el teléfono
/// en el bolsillo se entere de un pedido dentro de la ventana de respuesta.
///
/// Casi todo lo que decide si suena o no vive fuera de Dart —en el manifiesto y
/// en los canales de Android—, así que estos tests leen esos archivos. Un canal
/// mal escrito o un permiso que desaparece de una fusión no dan ningún error: la
/// notificación llega muda, o no llega, y nadie se entera hasta que un conductor
/// pierde pedidos.
void main() {
  const manifiesto = 'android/app/src/main/AndroidManifest.xml';
  const application =
      'android/app/src/main/kotlin/com/zumbeo/conductor/ZumbeoApplication.kt';

  group('Permisos del manifiesto', () {
    test('no se declara la ubicación en segundo plano', () {
      // Decisión de producto con consecuencias en la tienda: declarar
      // ACCESS_BACKGROUND_LOCATION activa la política de ubicación en segundo
      // plano de Google Play (justificación escrita, vídeo y revisión de
      // semanas), y su motivo de rechazo más común es precisamente que un
      // servicio en primer plano ya resuelva el caso — que es lo que hacemos.
      // No puede volver por un descuido.
      expect(
        File(manifiesto).readAsStringSync(),
        isNot(contains('ACCESS_BACKGROUND_LOCATION')),
      );
    });

    test('está el permiso de pantalla completa y el de la exención de batería', () {
      final xml = File(manifiesto).readAsStringSync();
      expect(xml, contains('USE_FULL_SCREEN_INTENT'));
      expect(xml, contains('REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'));
      // El servicio en primer plano es lo que mantiene el GPS vivo con la app
      // minimizada, y es la alternativa por la que no pedimos el permiso de
      // segundo plano. Sin él, la decisión de arriba deja de tener sentido.
      expect(xml, contains('FOREGROUND_SERVICE_LOCATION'));
    });

    test('el canal por defecto de FCM es el de avisos, no el de ofertas', () {
      // Este canal solo se usa cuando el mensaje no declara ninguno. Si fuera el
      // de ofertas, cualquier aviso suelto sonaría como un pedido y el conductor
      // aprendería a ignorar el sonido que no puede permitirse ignorar.
      expect(
        File(manifiesto).readAsStringSync(),
        contains('android:value="${CanalesNotificacion.avisos}"'),
      );
    });
  });

  group('Canales de notificación', () {
    test('el canal de ofertas suena por el flujo de audio de timbre', () {
      final kt = File(application).readAsStringSync();
      expect(kt, contains(CanalesNotificacion.oferta));
      // La pieza que resuelve el problema real: sin USAGE_NOTIFICATION_RINGTONE
      // el tono sale por el volumen de notificación, que en la mayoría de los
      // teléfonos está muy por debajo del de llamada.
      expect(kt, contains('USAGE_NOTIFICATION_RINGTONE'));
      expect(kt, contains('CONTENT_TYPE_SONIFICATION'));
      expect(kt, contains('IMPORTANCE_HIGH'));
    });

    test('las ofertas y los demás avisos van en canales distintos', () {
      // Con un canal único, un conductor harto de los avisos generales
      // silenciaría también los pedidos.
      expect(CanalesNotificacion.oferta, isNot(CanalesNotificacion.avisos));
      final kt = File(application).readAsStringSync();
      expect(kt, contains(CanalesNotificacion.avisos));
    });

    test('los ids llevan versión y los canales anteriores se borran', () {
      // Un NotificationChannel congela importancia y sonido en su PRIMERA
      // creación. Sin versión en el id, cambiar el tono sería imposible en los
      // teléfonos que ya tienen la app instalada — y el de ofertas ya la usó:
      // pasó a `_v2` al cambiar el tono del sistema por el propio.
      expect(CanalesNotificacion.oferta, matches(r'_v\d+$'));
      expect(CanalesNotificacion.avisos, matches(r'_v\d+$'));
      final kt = File(application).readAsStringSync();
      expect(kt, contains('deleteNotificationChannel'));
      expect(kt, contains('motoya_oferta_v1'));
      expect(kt, contains('motoya_alta_importancia_v2'));
    });

    test('el canal de ofertas suena con el tono propio, que existe', () {
      final kt = File(application).readAsStringSync();
      expect(kt, contains('raw/notisound'));
      // El recurso tiene que estar de verdad: un canal cuyo sonido no resuelve
      // es un canal MUDO, y el conductor perdería pedidos sin que nada fallara.
      expect(
        File('android/app/src/main/res/raw/notisound.ogg').existsSync(),
        isTrue,
        reason: 'Falta el tono de oferta en res/raw.',
      );
    });
  });

  group('El aviso suena venga la oferta por donde venga', () {
    test('el sondeo y STOMP también hacen sonar la oferta, no solo el push', () {
      // Esta es la regresión que dejó la app muda. El aviso colgaba solo del
      // handler de FCM, y el push depende de una credencial de servidor que
      // puede estar mal sin que nada falle a la vista. STOMP y el sondeo
      // funcionan siempre — y por ese camino no sonaba nada: la oferta aparecía
      // en la pantalla y ya. Con el teléfono en el bolsillo, eso es no
      // enterarse.
      final vm = File('lib/ui/features/inicio/inicio_view_model.dart')
          .readAsStringSync();
      expect(
        vm,
        contains('_sonarOferta'),
        reason: 'El Inicio dejó de avisar al detectar una oferta. Si el push '
            'no llega —y no hay nada que garantice que llega— la app se queda '
            'muda.',
      );
    });

    test('el handler de background sigue avisando con la app cerrada', () {
      expect(
        File('lib/data/services/push_service.dart').readAsStringSync(),
        contains('mostrarOferta('),
      );
    });

    test('el aviso no se duplica: es idempotente por pedido', () {
      // Push y sondeo pueden detectar la misma oferta. La comprobación va contra
      // las notificaciones ACTIVAS del sistema y no contra una variable, porque
      // el handler de background corre en otro isolate y no comparte memoria.
      final src = File('lib/data/services/notificacion_local_service.dart')
          .readAsStringSync();
      expect(src, contains('getActiveNotifications'));
      expect(src, contains('_yaEstaAvisado'));
    });
  });

  group('Lectura del mensaje de oferta', () {
    test('la oferta trae título y cuerpo en los datos, no en la notificación', () {
      // Va como mensaje de datos porque una notificación a pantalla completa no
      // se puede pedir desde el payload de FCM. Sin bloque de notificación, el
      // texto tiene que salir de `data` o el aviso llegaría en blanco.
      final m = PushMensaje.fromRemote(
        const RemoteMessage(
          data: {
            'tipo': 'PEDIDO_NUEVO',
            'pedidoId': '42',
            'titulo': '¡Nuevo pedido!',
            'cuerpo': 'Tienes un pedido cercano.',
            'segundosRestantes': '60',
          },
        ),
      );

      expect(m.tipo, PushMensaje.tipoOferta);
      expect(m.pedidoId, 42);
      expect(m.titulo, '¡Nuevo pedido!');
      expect(m.cuerpo, 'Tienes un pedido cercano.');
      expect(m.vigencia, const Duration(seconds: 60));
    });

    test('sin vigencia declarada el aviso no se retira solo', () {
      // Es peor un aviso que se va antes de tiempo que uno que se queda: si el
      // backend no dice cuánto dura, no se inventa un plazo.
      final m = PushMensaje.fromRemote(
        const RemoteMessage(data: {'tipo': 'PEDIDO_NUEVO', 'pedidoId': '7'}),
      );
      expect(m.vigencia, isNull);
    });

    test('un aviso que no es oferta no se confunde con una', () {
      final m = PushMensaje.fromRemote(
        const RemoteMessage(data: {'tipo': 'PROPUESTA', 'pedidoId': '9'}),
      );
      expect(m.tipo, isNot(PushMensaje.tipoOferta));
    });
  });
}

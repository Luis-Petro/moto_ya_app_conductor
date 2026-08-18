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
      // Los anteriores se borran para no dejarlos huérfanos en los Ajustes.
      for (final viejo in [
        'motoya_oferta_v3',
        'motoya_oferta_v2',
        'motoya_oferta_v1',
        'motoya_alta_importancia_v2',
      ]) {
        expect(kt, contains(viejo), reason: 'Dejó de borrarse $viejo');
      }
    });

    test('el patrón de vibración es el mismo en Kotlin y en Dart', () {
      // Un canal congela sonido, importancia Y VIBRACIÓN en su primera creación,
      // y lo crean las dos vías. Si declaran patrones distintos, el que gane
      // decide — y el resultado vuelve a depender del orden de arranque.
      const patron = '0, 600, 300, 600, 300, 900';
      expect(File(application).readAsStringSync(), contains(patron));
      expect(
        File('lib/data/services/notificacion_local_service.dart')
            .readAsStringSync(),
        contains(patron),
      );
    });

    test('el tono existe de verdad en res/raw', () {
      // Un canal cuyo sonido no resuelve no da error: Android cae al tono de
      // fábrica y el conductor deja de reconocer sus pedidos.
      expect(
        File('android/app/src/main/res/raw/'
                '${CanalesNotificacion.tonoOferta}.ogg')
            .existsSync(),
        isTrue,
        reason: 'Falta el tono de oferta en res/raw.',
      );
    });

    test('Kotlin y Dart declaran el MISMO canal y el MISMO tono', () {
      // Aquí estuvo el fallo que costó tres rondas. El canal lo crean dos sitios
      // —esta clase al arrancar el proceso y el plugin de Flutter en el primer
      // `show()`— y gana el que llegue primero, congelando el sonido para
      // siempre. Mientras uno declaraba el tono y el otro no, el resultado
      // dependía del orden de arranque: llegaba la notificación de llamada, pero
      // con el tono de fábrica.
      final kt = File(application).readAsStringSync();
      expect(
        kt,
        contains('"${CanalesNotificacion.oferta}"'),
        reason: 'El canal de Kotlin y el de Dart divergieron.',
      );
      expect(
        kt,
        contains('"${CanalesNotificacion.tonoOferta}"'),
        reason: 'El tono de Kotlin y el de Dart divergieron.',
      );
    });

    test('Kotlin y Dart declaran la MISMA importancia', () {
      // Misma trampa que el tono y que la vibración: el canal lo crean las dos
      // vías y gana la que llegue primero, congelando la importancia para
      // siempre. Mientras Kotlin decía IMPORTANCE_HIGH (4) y Dart Importance.max
      // (5), el valor final dependía del orden de arranque del teléfono.
      expect(File(application).readAsStringSync(), contains('IMPORTANCE_HIGH'));
      expect(
        File('lib/data/services/notificacion_local_service.dart')
            .readAsStringSync(),
        contains('importance: Importance.high'),
        reason: 'La importancia de Dart divergió de la de Kotlin.',
      );
    });

    test('el tono se declara también en la notificación, no solo en el canal', () {
      // Porque `show()` crea el canal si no existe, usando estos datos.
      final src = File('lib/data/services/notificacion_local_service.dart')
          .readAsStringSync();
      expect(src, contains('RawResourceAndroidNotificationSound'));
      expect(src, contains('AudioAttributesUsage.notificationRingtone'));
      expect(src, contains('createNotificationChannel'));
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

    test('el handler de background no pinta nada: lo hace el SDK de FCM', () {
      // La oferta se mandó un tiempo como mensaje solo de datos para poder
      // construir aquí el aviso a pantalla completa. Salió mal: un mensaje de
      // datos necesita que este isolate despierte, y en los teléfonos de gama
      // media que son el parque real muchas veces no despierta — ni
      // notificación, ni sonido, ni error. Sonar siempre vale más que sonar a
      // pantalla completa a veces.
      expect(
        File('lib/data/services/push_service.dart').readAsStringSync(),
        isNot(contains('mostrarOferta(')),
        reason: 'El handler de background vuelve a pintar el aviso. Si el '
            'backend manda bloque de notificación, saldrían dos.',
      );
    });

    test('hay una forma de probar el tono sin esperar un pedido', () {
      // "No me suena" no se puede investigar: permiso, canal, sonido del canal,
      // canal silenciado a mano y teléfono en vibración se ven todos igual desde
      // fuera. Y la prueba manda EL MISMO aviso que una oferta real, porque una
      // comprobación que difiere del camino real certifica el camino equivocado.
      final src = File('lib/data/services/notificacion_local_service.dart')
          .readAsStringSync();
      expect(src, contains('Future<String> probarTono()'));
      expect(src, contains('mostrarOferta('));
      expect(src, contains('Future<String> diagnostico()'));
      expect(
        File('lib/ui/features/perfil/perfil_screen.dart').readAsStringSync(),
        contains('probarTono()'),
      );
    });

    test('el aviso insiste dentro de la ventana y para al cerrarse la oferta', () {
      // Se repite, no se alarga: un motor no baja el volumen del tono, lo
      // enmascara, y si no atraviesa en los primeros segundos tampoco lo hará al
      // décimo. Lo que cambia el resultado es cuántas oportunidades tiene,
      // porque una moto para en los semáforos.
      final src = File('lib/data/services/notificacion_local_service.dart')
          .readAsStringSync();
      expect(src, contains('_insistencias'));
      // Y para en seco al retirarse la oferta: sonar por un pedido que ya tomó
      // otro enseña al conductor a desconfiar del aviso.
      expect(src, contains('_cancelarInsistencias'));
      expect(
        src,
        contains('if (vigencia != null && cuando >= vigencia) continue;'),
        reason: 'Una insistencia programada después de que la oferta venza '
            'suena por un pedido que ya no existe.',
      );
    });

    test('la prueba de tono suena aunque se apriete dos veces seguidas', () {
      // El aviso vive 30 s y el guardado anti-duplicados descartaba en silencio
      // el segundo toque. Quien prueba un sonido aprieta tres veces seguidas.
      final src = File('lib/data/services/notificacion_local_service.dart')
          .readAsStringSync();
      final prueba = src.substring(src.indexOf('Future<String> probarTono()'));
      expect(prueba.contains('retirarOferta(_pedidoDePrueba)'), isTrue);
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

  group('Por qué NO suena: lo que solo sabe Android', () {
    const actividad =
        'android/app/src/main/kotlin/com/zumbeo/conductor/MainActivity.kt';

    test('el diagnóstico pregunta al sistema, no solo a sí mismo', () {
      // El diagnóstico anterior solo se miraba a sí mismo: "el canal existe, con
      // su tono y su importancia alta" seguía siendo cierto en TODOS los
      // teléfonos en los que el conductor no oyó el pedido. Las causas reales
      // —No molestar, el canal apagado a mano, la app restringida en segundo
      // plano— viven en los servicios de Android y no las expone ningún plugin.
      final kt = File(actividad).readAsStringSync();
      expect(kt, contains('currentInterruptionFilter'));
      expect(kt, contains('canBypassDnd'));
      expect(kt, contains('isBackgroundRestricted'));
      expect(kt, contains('isIgnoringBatteryOptimizations'));
      expect(kt, contains('areNotificationsEnabled'));

      final src = File('lib/data/services/notificacion_local_service.dart')
          .readAsStringSync();
      expect(src, contains('estadoDelSistema()'));
      expect(
        src.substring(src.indexOf('Future<String> diagnostico()')),
        contains('estadoDelSistema()'),
        reason: 'El diagnóstico dejó de leer el estado real del sistema.',
      );
    });

    test('el nombre del canal de métodos es el mismo en Kotlin y en Dart', () {
      // Un nombre que no coincide no da error: `invokeMethod` lanza
      // MissingPluginException, la app lo traga y el diagnóstico vuelve a decir
      // "todo en orden" — que es justo el fallo que se estaba resolviendo.
      const canal = 'zumbeo/avisos';
      expect(File(actividad).readAsStringSync(), contains('"$canal"'));
      expect(
        File('lib/data/services/notificacion_local_service.dart')
            .readAsStringSync(),
        contains("MethodChannel('$canal')"),
      );
    });

    test('un estado no disponible NO se lee como "todo en orden"', () {
      // Fuera de Android, o si la capa del fabricante no responde, el estado
      // llega vacío. Si los valores por defecto contaran como diagnóstico, la
      // app afirmaría que nada silencia los pedidos justo cuando no tiene ni
      // idea — la respuesta más peligrosa que puede dar.
      const sinDatos = EstadoAvisos();
      expect(sinDatos.disponible, isFalse);
      expect(sinDatos.motivoDeSilencio, isNull);
      expect(sinDatos.puedePerderAvisosConLaAppCerrada, isFalse);
    });

    test('cada causa de silencio se nombra, y el orden es el de resolución', () {
      // "No me suena" tiene media docena de causas idénticas desde fuera. Cada
      // una tiene su frase porque cada una se arregla en un sitio distinto.
      expect(
        const EstadoAvisos(disponible: true, avisosActivados: false)
            .motivoDeSilencio,
        contains('desactivadas'),
      );
      expect(
        const EstadoAvisos(disponible: true, canalSilenciado: true)
            .motivoDeSilencio,
        contains('silenciado'),
      );
      expect(
        const EstadoAvisos(
          disponible: true,
          filtroDeInterrupciones: 'solo prioritarias',
        ).motivoDeSilencio,
        contains('No molestar'),
      );
      expect(
        const EstadoAvisos(disponible: true, restringidaEnSegundoPlano: true)
            .motivoDeSilencio,
        contains('segundo plano'),
      );
    });

    test('No molestar no se denuncia si el canal está autorizado a saltárselo', () {
      // Solo lo concede el conductor desde los Ajustes; ningún permiso de la app
      // lo da. Cuando lo ha concedido, avisarle de No molestar sería mandarlo a
      // arreglar algo que ya está arreglado.
      expect(
        const EstadoAvisos(
          disponible: true,
          filtroDeInterrupciones: 'solo prioritarias',
          puedeSaltarNoMolestar: true,
        ).motivoDeSilencio,
        isNull,
      );
    });

    test('con todo en orden no se inventa un problema', () {
      expect(const EstadoAvisos(disponible: true).motivoDeSilencio, isNull);
    });

    test('la app puede llevar al conductor a los ajustes DEL CANAL', () {
      // No a los de la app: la diferencia entre una pantalla ya abierta en el
      // sitio y "ve a Ajustes, busca Zumbeo, entra en notificaciones, busca
      // Pedidos entrantes". Subir la importancia o permitir saltarse No molestar
      // solo lo puede hacer él — Android no deja que una app se lo conceda.
      expect(
        File(actividad).readAsStringSync(),
        contains('ACTION_CHANNEL_NOTIFICATION_SETTINGS'),
      );
      expect(
        File('lib/ui/features/perfil/perfil_screen.dart').readAsStringSync(),
        contains('abrirAjustesDelCanal()'),
      );
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

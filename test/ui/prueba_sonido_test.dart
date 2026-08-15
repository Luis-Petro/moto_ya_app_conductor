import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La prueba de sonido le habla al conductor; el diagnóstico va detrás.
///
/// El diálogo terminaba con nueve líneas técnicas, una de ellas
/// `Instance of 'RawResourceAndroidNotificationSound'` — texto de depuración de
/// Dart en la pantalla de un conductor, que además tapaba el único dato que
/// importa ahí: qué tono quedó configurado.
///
/// Son comprobaciones sobre el código porque leer los canales de Android exige
/// el plugin y un teléfono: lo que se puede vigilar aquí es que nadie vuelva a
/// interpolar el objeto ni a sacar el volcado a la primera pantalla.
void main() {
  const servicio = 'lib/data/services/notificacion_local_service.dart';
  const perfil = 'lib/ui/features/perfil/perfil_screen.dart';

  test('el sonido del canal se redacta, no se interpola', () {
    final src = File(servicio).readAsStringSync();

    expect(
      src,
      isNot(contains(r'${oferta.sound')),
      reason: 'Interpolar el objeto imprime "Instance of \'…\'": '
          'AndroidNotificationSound no tiene toString() propio.',
    );
    expect(src, contains('_sonido(oferta.sound)'));
    expect(src, contains('RawResourceAndroidNotificationSound r =>'));
  });

  test('un canal sin sonido se nombra como mudo', () {
    // Es la causa que se está buscando cuando alguien reporta "no me suena".
    expect(File(servicio).readAsStringSync(), contains('canal mudo'));
  });

  test('la importancia lleva su nombre además del número', () {
    final src = File(servicio).readAsStringSync();
    expect(src, contains('_importancia(oferta.importance)'));
    expect(src, contains("4 => 'alta'"));
  });

  test('el diagnóstico no está en pantalla, ni siquiera plegado', () {
    // Antes este test exigía lo contrario: que el volcado estuviera detrás de
    // un "Ver detalle técnico". Plegarlo no bastaba — un desplegable con ese
    // nombre es una invitación a abrirlo, entender menos y desconfiar más de
    // una app que acaba de funcionar. Ahora el diálogo solo le habla al
    // conductor.
    final src = File(perfil).readAsStringSync();

    expect(
      src,
      isNot(contains("Text('Ver detalle técnico'")),
      reason: 'El diálogo de la prueba de sonido no puede ofrecer el volcado '
          'técnico, ni plegado tras una acción.',
    );
    expect(
      src,
      isNot(contains('ExpansionTile')),
      reason: 'No queda ningún desplegable en el diálogo de la prueba.',
    );
  });

  test('el diagnóstico se sigue recogiendo y sale por el log', () {
    // Quitarlo de la vista no puede significar perderlo: es lo único que
    // convierte "no me suena" —permiso denegado, canal inexistente, canal
    // mudo, canal silenciado a mano o teléfono en vibración, indistinguibles
    // desde fuera— en una causa concreta.
    final src = File(perfil).readAsStringSync();

    expect(src, contains('probarTono()'));
    expect(
      src,
      contains("debugPrint('[prueba de tono]"),
      reason: 'El estado del canal tiene que quedar en el log de la app.',
    );
  });
}

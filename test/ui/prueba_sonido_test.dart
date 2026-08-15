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

  test('el diagnóstico va plegado, no de entrada', () {
    final src = File(perfil).readAsStringSync();

    expect(src, contains('Ver detalle técnico'));
    expect(
      src,
      contains('ExpansionTile'),
      reason: 'El detalle técnico tiene que estar detrás de una acción '
          'explícita, no ser lo primero que se lee al probar el sonido.',
    );
  });
}

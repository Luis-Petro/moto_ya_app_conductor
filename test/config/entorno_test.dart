import 'package:app_conductor/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

/// La marca de entorno del encabezado se **deriva** de la URL de la API. Este
/// test protege la mitad que no se ve en una captura: que la build de
/// producción —la que se sube a Google Play— no se anuncie como de pruebas, y
/// que la de pruebas sí.
///
/// Los tests corren sin `--dart-define`, así que `Env.apiBaseUrl` toma su valor
/// por defecto: el de producción. Eso es exactamente lo que hace falta afirmar
/// aquí — si alguien cambiara el default a la API de pruebas, el APK de tienda
/// saldría hablando con el backend equivocado y este test es lo único que lo
/// diría.
void main() {
  group('Env.esProduccion', () {
    test('la build por defecto es la de producción', () {
      expect(Env.apiBaseUrl, 'https://api.zumbeo.com/Api');
      expect(Env.esProduccion, isTrue);
    });

    test('el WebSocket apunta al mismo host que la API', () {
      // Si se separaran, una app podría pedir por REST a un entorno y escuchar
      // el tiempo real del otro: los pedidos existirían y no llegaría ni una
      // posición, sin ningún error.
      expect(Env.wsTrackingUrl.startsWith('https://api.zumbeo.com/'), isTrue);
    });
  });
}

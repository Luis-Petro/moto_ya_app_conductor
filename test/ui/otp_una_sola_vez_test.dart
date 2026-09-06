import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El código de un solo uso, verificado una sola vez.
///
/// `OtpService` del backend borra el código al acertar, así que **la segunda
/// verificación del mismo código recibe un 401** — y lo que queda en pantalla
/// es el acuse de la segunda: «el código no es correcto» sobre un código que sí
/// lo era. Pasa solo, sin que nadie haga nada raro: el autocompletado del SMS
/// llena las cuatro cajas y dispara `onChanged`, y acto seguido la persona pulsa
/// «Verificar» sobre unas cajas que ya se ven llenas.
///
/// Se comprueba sobre la fuente y no montando la pantalla porque lo que hay que
/// impedir es que alguien quite la guarda: un test de widget que teclee cuatro
/// dígitos no reproduce el segundo toque del botón sin fabricar la carrera a
/// mano, y esa carrera depende del tiempo de red.
void main() {
  final otp = File('lib/ui/features/auth/otp_screen.dart').readAsStringSync();

  test('la verificación tiene guarda de reentrada', () {
    expect(otp, contains('if (_enVuelo) return;'),
        reason: 'sin guarda, el auto-disparo del cuarto dígito y el botón '
            'consumen el código dos veces');
  });

  /// Un texto fijo hacía indistinguibles un código vencido (401), un código
  /// **quemado** tras cinco intentos (429) y un fallo de envío (502). El 429 es
  /// el peor: el código ya no existe y la pantalla invitaba a «revisarlo e
  /// intentarlo de nuevo», así que la salida obvia no podía funcionar nunca.
  test('el motivo del fallo lo dice el servidor', () {
    expect(otp, contains('vm.error ??'),
        reason: 'el motivo real del fallo no llega a la pantalla');
  });

  /// Guardar la sesión notifica al `refreshListenable` del router, y su redirect
  /// saca esta ruta de las de acceso: la pantalla se desmonta mientras la
  /// verificación está en vuelo, y un `context` de después del await ya no
  /// sirve para navegar.
  test('se navega con un router tomado antes del await', () {
    expect(otp, contains('GoRouter.of(context)'),
        reason: 'el router se toma después del await y la navegación se pierde');
  });
}

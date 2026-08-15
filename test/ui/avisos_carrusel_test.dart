import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Los avisos de configuración van en una fila deslizable; lo que tiene reloj
/// corriendo, no.
///
/// Un conductor nuevo cumplía a la vez las condiciones de revisión, foto y
/// batería: tres bloques del mismo naranja, más el interruptor en rojo, antes de
/// llegar al mapa. El riesgo del arreglo es el contrario —esconder algo que no
/// puede esconderse—, y eso es lo que vigilan estas comprobaciones: una oferta
/// que hay que descubrir deslizando se vence sola y le baja la tasa de
/// aceptación al conductor por algo que la pantalla no le enseñó.
void main() {
  final inicio =
      File('lib/ui/features/inicio/inicio_screen.dart').readAsStringSync();

  /// La declaración de la lista de avisos, que es la que decide quién entra.
  final lista = inicio.substring(
    inicio.indexOf('final avisos = <Widget>['),
    inicio.indexOf('final hayAvisos'),
  );

  final carrusel = inicio.substring(
    inicio.indexOf('class _AvisosCarrusel'),
    inicio.indexOf('class _ActivoBanner'),
  );

  group('Qué entra al carrusel', () {
    test('los cuatro avisos de configuración', () {
      expect(lista, contains('_RevisionBanner'));
      expect(lista, contains('_FotoPerfilBanner'));
      expect(lista, contains('_SinVisibilidadBanner'));
      expect(lista, contains('_BateriaBanner'));
    });

    test('el pedido en curso, la oferta y el toggle se quedan fuera', () {
      expect(lista, isNot(contains('_ActivoBanner')));
      expect(lista, isNot(contains('_OfertaBanner')));
      expect(lista, isNot(contains('_ToggleEnLinea')));
    });

    test('el orden es por lo que bloquea cada aviso', () {
      // Sin habilitar no hay nada más que hacer; sin foto no se puede uno poner
      // en línea; sin visibilidad no llegan ofertas; la batería solo se lleva
      // las que entran con la app cerrada.
      final orden = [
        lista.indexOf('_RevisionBanner'),
        lista.indexOf('_FotoPerfilBanner'),
        lista.indexOf('_SinVisibilidadBanner'),
        lista.indexOf('_BateriaBanner'),
      ];
      expect(orden, orderedEquals(List<int>.from(orden)..sort()));
    });
  });

  group('Comportamiento del carrusel', () {
    test('con un solo aviso no hay carrusel', () {
      // Un carrusel de una página es un carrusel roto: puntos, contador y un
      // gesto que no lleva a ninguna parte.
      expect(carrusel, contains('if (avisos.length == 1) return avisos.single'));
    });

    test('no avanza solo', () {
      // Cada tarjeta tiene una acción a un toque; una que se mueve sola se
      // pulsa por error.
      expect(carrusel, isNot(contains('Timer')));
      expect(carrusel, isNot(contains('autoPlay')));
    });

    test('dice en cuál va y cuántos hay', () {
      expect(carrusel, contains(r'${actual + 1} de ${avisos.length}'));
    });

    test('la página actual no se sale al resolverse un aviso', () {
      // La lista encoge cuando el conductor sube su foto: sin esto el contador
      // diría "4 de 3".
      expect(carrusel, contains('clamp(0, avisos.length - 1)'));
    });
  });

  test('el detalle largo de la batería no se pierde: vive en su hoja', () {
    // Es la instrucción que más ha hecho falta en el piloto, y cada marca
    // esconde esa pantalla en un sitio distinto.
    expect(inicio, contains('Inicio automático'));
    expect(inicio, contains('showModalBottomSheet<bool>'));
  });
}

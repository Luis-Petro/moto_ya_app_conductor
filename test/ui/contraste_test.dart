import 'dart:math' as math;
import 'dart:ui';

import 'package:app_conductor/ui/core/theme/app_colors.dart';
import 'package:app_conductor/ui/core/theme/app_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contraste WCAG de los pares de color que la app usa de verdad.
///
/// Es aritmética sobre constantes, así que cuesta milisegundos y convierte la
/// accesibilidad en un hecho comprobable en vez de una intención.
///
/// En esta app pesa el doble que en la del cliente: el conductor la mira **al
/// sol, en la calle y en movimiento**. Un rótulo a 3:1 que en un escritorio se
/// lee, ahí no.
///
/// Al escribirse destapó cuatro fallos con uso real en el código, todos
/// corregidos con la tinta correspondiente:
///
/// - `inkMuted` a 4,48:1 sobre el fondo —a dos centésimas de AA— con ~90 usos.
/// - El distintivo "Entregado" de la billetera, `success` sobre
///   `successSurface`: **2,74:1**, verde claro sobre verde más claro.
/// - El aviso ámbar de "te falta un documento" sobre blanco: **2,15:1**, y es
///   justo lo que hay que leer.
/// - "Cerrar sesión" y la baja de cuenta en `danger` sobre blanco: 3,91:1.
///
/// Regla que sale de aquí: `<color>Ink` para texto, `<color>` para rellenos,
/// bordes, iconos y marcadores.
double _luminancia(Color c) {
  double canal(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

double contraste(Color a, Color b) {
  final la = _luminancia(a);
  final lb = _luminancia(b);
  final claro = math.max(la, lb);
  final oscuro = math.min(la, lb);
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  /// Texto normal. El listón grande (3:1) solo aplica a 24 dp o a 19 dp en
  /// negrita, y ninguno de estos pares se usa solo en ese tamaño.
  const minimoAA = 4.5;

  /// Elementos no textuales (bordes de foco, iconos de estado).
  const minimoNoTexto = 3.0;

  final paresTexto = <String, (Color, Color)>{
    'primaryInk sobre surface': (AppColors.primaryInk, AppColors.surface),
    'primaryInk sobre background': (AppColors.primaryInk, AppColors.background),
    'primaryInk sobre primarySurface': (
      AppColors.primaryInk,
      AppColors.primarySurface
    ),
    'blanco sobre accent': (const Color(0xFFFFFFFF), AppColors.accent),
    'ink sobre surface': (AppColors.ink, AppColors.surface),
    'ink sobre background': (AppColors.ink, AppColors.background),
    'inkMuted sobre surface': (AppColors.inkMuted, AppColors.surface),
    'inkMuted sobre background': (AppColors.inkMuted, AppColors.background),
    'inkMuted sobre surfaceMuted': (AppColors.inkMuted, AppColors.surfaceMuted),
    'dangerInk sobre dangerSurface': (
      AppColors.dangerInk,
      AppColors.dangerSurface
    ),
    'dangerInk sobre surface': (AppColors.dangerInk, AppColors.surface),
    'successInk sobre successSurface': (
      AppColors.successInk,
      AppColors.successSurface
    ),
    'successInk sobre surface': (AppColors.successInk, AppColors.surface),
    'warningInk sobre warningSurface': (
      AppColors.warningInk,
      AppColors.warningSurface
    ),
    'warningInk sobre surface': (AppColors.warningInk, AppColors.surface),
    // Propio del conductor: la tarjeta de pedido en curso y el control "En
    // línea" activo pintan sobre navy, y su segunda línea se resolvía con
    // `Colors.white70` suelto. El token existe para que ese caso tenga dueño.
    'onAccentMuted sobre accent': (AppColors.onAccentMuted, AppColors.accent),
  };

  for (final par in paresTexto.entries) {
    test('${par.key} pasa AA para texto', () {
      final ratio = contraste(par.value.$1, par.value.$2);
      expect(
        ratio,
        greaterThanOrEqualTo(minimoAA),
        reason: '${par.key}: ${ratio.toStringAsFixed(2)}:1 '
            '(mínimo $minimoAA:1)',
      );
    });
  }

  test('el CTA naranja pasa AA como texto grande', () {
    // El blanco sobre el naranja de marca da 3,17:1 y NO llega al 4,5:1 de
    // texto normal. La salida no fue oscurecer la marca —el naranja es lo
    // primero que se reconoce de Zumbeo— sino cumplir por el otro lado: WCAG
    // baja el listón a 3:1 desde 18,66 px en negrita, y `AppText.cta` son
    // 19 dp en peso 800. El botón es accesible y el naranja no se toca.
    //
    // Los dos hechos van juntos en un solo caso a propósito: si alguien baja
    // el tamaño del CTA "porque cabe mejor", esto se pone rojo y explica por
    // qué era 19.
    expect(AppText.cta.fontSize, greaterThanOrEqualTo(18.66));
    expect(AppText.cta.fontWeight!.value, greaterThanOrEqualTo(700));
    expect(
      contraste(const Color(0xFFFFFFFF), AppColors.primary),
      greaterThanOrEqualTo(minimoNoTexto),
      reason: 'Si el naranja cambia y baja de 3:1, el CTA deja de ser '
          'accesible ni siquiera como texto grande.',
    );
  });

  test('nada pequeño se escribe en blanco sobre el naranja', () {
    // Corolario del caso anterior, escrito para que no se olvide: el 3:1 solo
    // vale para texto grande. La segunda línea del CTA ("Comida, farmacia,
    // mercado o mandados") va en `caption`, y en blanco sobre naranja sería
    // 3,17:1 a 12 dp — falla. Va sobre otra superficie o no va.
    expect(AppText.caption.fontSize, lessThan(18.66));
    expect(
      contraste(const Color(0xFFFFFFFF), AppColors.primary),
      lessThan(minimoAA),
    );
  });

  test('el naranja de relleno se distingue del blanco', () {
    // `primary` como **relleno** no necesita 4,5:1, pero sí separarse del
    // fondo lo bastante para que el borde del CTA se vea.
    expect(
      contraste(AppColors.primary, AppColors.surface),
      greaterThanOrEqualTo(minimoNoTexto),
    );
  });

  test('la estrella vacía se ve sobre blanco', () {
    // Lo que separa una estrella llena de una vacía es la **forma** del icono
    // (relleno contra contorno), no la luminancia. Este caso comprueba lo otro:
    // que el contorno se vea. En `star` (ámbar) daba 2,15:1 y a tamaño 16 no se
    // veía, que es de donde salió `starEmpty`.
    expect(
      contraste(AppColors.starEmpty, AppColors.surface),
      greaterThanOrEqualTo(minimoNoTexto),
    );
  });

  test('la estrella vacía es más visible que el ámbar que sustituye', () {
    // El primer valor de `starEmpty` fue un gris claro que daba 1,67:1: más
    // apagado que el ámbar, o sea una regresión con aspecto de arreglo. Este
    // caso existe para que ese error concreto no se pueda repetir — un gris
    // "más suave" que parezca mejor idea vuelve a ponerlo rojo.
    expect(
      contraste(AppColors.starEmpty, AppColors.surface),
      greaterThan(contraste(AppColors.star, AppColors.surface)),
    );
  });

  test('primary NO sirve como color de texto sobre blanco', () {
    // Este caso documenta el motivo de que exista `primaryInk`. Si algún día
    // alguien "arregla" la paleta subiendo `primary`, este test se pone rojo y
    // obliga a revisar los dos tokens juntos, no uno suelto.
    expect(
      contraste(AppColors.primary, AppColors.surface),
      lessThan(minimoAA),
      reason: 'Si primary ya pasara AA, primaryInk sobraría: revisar ambos.',
    );
  });
}

import 'package:flutter/material.dart';

/// Paleta de marca Zumbeo, alineada al logo (naranja + azul marino).
///
/// **Regla de una línea que resuelve casi todo este archivo:** `<color>` para
/// rellenos, bordes, iconos y marcadores; `<color>Ink` para **texto**. Son dos
/// tokens y no una función `oscurecer()` porque una función invita a llamarla
/// con cualquier factor, y entonces cada pantalla vuelve a decidir su contraste.
///
/// Los pares que la app usa de verdad los comprueba `test/ui/contraste_test.dart`
/// con aritmética WCAG. Si se toca un valor de aquí, ese test es quien manda.
class AppColors {
  const AppColors._();

  // Marca (naranja del logo)
  static const Color primary = Color(0xFFF2641E); // naranja Zumbeo (CTAs)
  static const Color primaryDark = Color(0xFFC94E12);
  static const Color primaryLight = Color(0xFFF59A5E);
  static const Color primarySurface = Color(
    0xFFFCEDE4,
  ); // fondos suaves naranja

  /// El naranja de marca **como texto**. `primary` sobre blanco da 3,1:1 y no
  /// pasa AA, así que un enlace o un rótulo de estado escrito en naranja se lee
  /// mal al sol — que es exactamente donde se usa esta app: en la calle, sobre
  /// una moto. Mismo valor que `--primary-ink` de la landing y que el de
  /// `app_cliente`: la web y las dos apps dicen lo mismo.
  static const Color primaryInk = Color(0xFFB8460B);

  /// Estado pulsado del CTA. Sin él, el `InkWell` lo resuelve con un velo gris
  /// que sobre el naranja se ve sucio.
  static const Color primaryPressed = Color(0xFFD9551A);

  // Acento (azul marino del logo) — énfasis de precio / contraoferta
  static const Color accent = Color(0xFF17293D);
  static const Color accentSurface = Color(0xFFE9EEF3);

  /// Texto secundario **sobre la superficie navy** (tarjeta de pedido en curso,
  /// control "En línea" cuando está activo).
  ///
  /// Existe porque esos dos sitios lo resolvían con `Colors.white70` suelto. No
  /// era un fallo de contraste —da por encima de 7:1— sino de sistema: sin token
  /// para este caso, cada pantalla inventa el suyo y la regla de "ningún color
  /// del framework en `features/`" deja de poder aplicarse sin excepciones.
  ///
  /// Es opaco a propósito y no un blanco con alfa: el color efectivo es el mismo
  /// sobre `accent`, pero así el contraste se puede medir sin suponer qué hay
  /// detrás.
  static const Color onAccentMuted = Color(0xFFB9BFC5);

  // Estados. Cada uno tiene su relleno, su superficie suave y su tinta.
  //
  // La tinta no es simetría decorativa: el distintivo "Entregado" de la billetera
  // era `success` sobre `successSurface`, o sea **2,74:1** — verde claro sobre
  // verde más claro, ilegible al sol y para cualquiera con la vista cansada. El
  // ámbar de "te falta un documento" sobre blanco daba **2,15:1**, y es
  // precisamente el aviso que hay que leer. El rojo de "Cerrar sesión", 3,91:1.
  static const Color success = Color(0xFF1FA971);
  static const Color successSurface = Color(0xFFEAF7F1);
  static const Color successInk = Color(0xFF177F55);
  static const Color danger = Color(0xFFE5484D);
  static const Color dangerSurface = Color(0xFFFDEBEC);
  static const Color dangerInk = Color(0xFFD51E24);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFEF3E2);
  static const Color warningInk = Color(0xFF9C6406);

  // Neutros (texto en azul marino del logo)
  static const Color ink = Color(0xFF17293D); // texto principal

  /// Texto secundario. Era `#64748B`, que sobre el fondo de la app daba 4,48:1 y
  /// se quedaba a dos centésimas de AA — el tipo de fallo que nadie ve en una
  /// revisión de código y que se nota en la calle. Es un gris neutro, no un color
  /// de marca: oscurecerlo no cambia la identidad.
  static const Color inkMuted = Color(0xFF617187);
  static const Color line = Color(0xFFE3E8EE); // bordes/divisores
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7F8FA);
  static const Color mapPlaceholder = Color(0xFFDFE5EC);

  /// Superficie de segundo plano **dentro** de una tarjeta (la caja del desglose
  /// de la tarifa, el bloque de datos de pago). Distinta de `background`: ahí el
  /// contraste se mide contra un gris más oscuro, y `inkMuted` tiene que seguir
  /// pasando AA encima.
  static const Color surfaceMuted = Color(0xFFF1F4F8);

  /// Tinte de las sombras. Es la tinta de marca, no negro: sobre `background` un
  /// negro puro se lee como suciedad, no como profundidad. El alfa lo pone cada
  /// nivel de `AppElevation`.
  static const Color shadow = ink;

  /// Relleno de los bloques de carga (`Skeleton`).
  ///
  /// Tiene que ser bastante más oscuro que `line` o `mapPlaceholder` porque el
  /// fondo ya es casi blanco y el bloque se pinta **con opacidad**: sobre
  /// `background` da 1,42:1 en el punto más apagado de la animación y 1,84:1 a
  /// opacidad plena. Con `line` (#E3E8EE) daba **1,06:1**, que es literalmente una
  /// pantalla vacía; con `mapPlaceholder` da 1,19:1 incluso sin animar.
  ///
  /// **Diverge de `app_cliente` a propósito** (allí es `#E8ECF1`, que aquí daría
  /// 1,07:1): esta pantalla se mira al sol. `test/ui/skeleton_visible_test.dart`
  /// fija el suelo en 1,4:1 y comprueba además que el gris del cliente no lo
  /// pasaría, para que unificar "porque son la misma marca" no sea un cambio
  /// silencioso.
  static const Color skeleton = Color(0xFFB3BAC5);

  /// Brillo que recorre el esqueleto.
  ///
  /// **Diverge de `app_cliente` por el mismo motivo que `skeleton`.** Allí es
  /// `#F4F6F9`, casi el blanco del fondo: contra `background` da **1,01:1**, así
  /// que la banda de brillo desaparece. En el cliente eso es un bache local en
  /// una franja estrecha; aquí sería un trozo de pantalla que no está, al sol.
  ///
  /// Este valor es un `skeleton` **aclarado**, no un casi-blanco: el barrido se
  /// lee como movimiento (1,84:1 en el bloque, 1,42:1 en la banda) sin que
  /// ningún punto del ciclo baje del suelo. Lo comprueba
  /// `test/ui/skeleton_visible_test.dart` en los dos extremos del degradado.
  static const Color skeletonHighlight = Color(0xFFCDD3DC);

  static const Color star = Color(0xFFF5A623);

  /// La estrella **vacía** de una calificación. No usa `star` con opacidad: en
  /// ámbar claro sobre blanco daba 2,15:1 y a tamaño 16 no se distinguía de una
  /// llena, que es justo lo único que una calificación tiene que dejar claro.
  ///
  /// El valor es un gris medio (3,14:1 sobre blanco) y no uno claro. El primer
  /// intento fue `#C2C9D4`, que daba **1,67:1**: más apagado que el ámbar que
  /// venía a sustituir, o sea una regresión con aspecto de arreglo. Lo destapó
  /// `contraste_test.dart` en la misma tarde.
  ///
  /// Lo que separa llena de vacía es la **forma** del icono (relleno contra
  /// contorno), no la luminancia: el ámbar y cualquier gris legible están cerca
  /// en luminancia y pedirles 3:1 entre sí obligaría a un gris tan oscuro que la
  /// estrella vacía parecería llena. Este token solo tiene que garantizar que el
  /// contorno **se ve**.
  static const Color starEmpty = Color(0xFF8A929E);
}

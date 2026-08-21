import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';

/// Barra de navegación inferior de las dos apps.
///
/// Vive aquí y no en cada shell porque es el sitio más tocado de la app y las
/// dos tienen que verse como la misma marca: mientras cada shell montaba su
/// propio `BottomNavigationBar`, el de cliente tenía píldora, háptico y sombra
/// y el de conductor no tenía ninguna de las tres, sin que nada lo delatara.
///
/// Reglas que codifica, todas comprobables:
///
/// - **La pestaña activa cambia por tres vías a la vez** (forma, color y peso
///   del texto), no solo por color. Naranja y gris se distinguen mal de reojo
///   —que es como se mira esta barra— y no se distinguen en absoluto para quien
///   no separa esos dos tonos.
/// - **El color activo es `primaryInk`, no `primary`.** El naranja de marca
///   como texto da 3,17:1 sobre blanco y no pasa AA; sobre la píldora
///   (`primarySurface`) da 2,78:1 y ni siquiera llega al 3:1 de elemento no
///   textual. Es la misma regla que ya vigila `contraste_test.dart` para el
///   resto de la app, y la barra era el único sitio que la incumplía.
/// - **La barra se separa del contenido** con borde de 1 px *y* sombra hacia
///   arriba. Los dos juntos, igual que `MotoCard`: la sombra sola desaparece
///   cuando lo que hay encima es una tarjeta blanca, y el borde solo desaparece
///   a pleno sol.
/// - **El toque se acusa antes de que llegue el primer fotograma.** Cambiar de
///   pestaña reconstruye la rama y en un teléfono de gama media eso se nota; el
///   háptico llega antes y la navegación se siente inmediata igual.
class BarraNavegacion extends StatelessWidget {
  const BarraNavegacion({
    super.key,
    required this.indice,
    required this.destinos,
    required this.onSeleccion,
  });

  final int indice;
  final List<DestinoNav> destinos;
  final ValueChanged<int> onSeleccion;

  @override
  Widget build(BuildContext context) {
    // `Container` y no `DecoratedBox`: un borde en una decoración de fondo lo
    // taparía el Material opaco de la barra. Container añade el grosor del
    // borde como relleno del hijo, así que la línea se ve.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.line)),
        boxShadow: AppElevation.anclada,
      ),
      child: BottomNavigationBar(
        currentIndex: indice,
        onTap: (i) {
          HapticFeedback.selectionClick();
          onSeleccion(i);
        },
        items: [
          for (var i = 0; i < destinos.length; i++)
            BottomNavigationBarItem(
              // Sin `activeIcon`: un solo widget que sabe si está activo es lo
              // que permite animar el cambio. Con dos widgets distintos,
              // Material los intercambia de golpe y no hay nada que animar.
              icon: _IconoNav(destino: destinos[i], activo: i == indice),
              label: destinos[i].etiqueta,
            ),
        ],
      ),
    );
  }
}

/// Una pestaña de [BarraNavegacion].
class DestinoNav {
  const DestinoNav({
    required this.icono,
    required this.iconoActivo,
    required this.etiqueta,
    this.aviso,
  });

  /// Icono en reposo. Contorno en las cuatro pestañas: mezclar contorno y
  /// relleno entre pestañas rompe la unidad de la barra, y deja sin significado
  /// al relleno, que es justo lo que marca la activa.
  final IconData icono;

  /// El mismo icono relleno. Es el cambio de **forma** que distingue la
  /// pestaña activa sin depender del color.
  final IconData iconoActivo;

  /// Una sola línea, corta. Dos renglones engordan la barra y se comen la
  /// pantalla.
  final String etiqueta;

  /// Texto del punto de aviso, o `null` para no pintarlo. No es un booleano
  /// porque un punto de color no le dice nada a un lector de pantalla: la misma
  /// cadena enciende el punto y es lo que se anuncia.
  ///
  /// Solo para lo que exige una acción del usuario (el bloqueo por deuda del
  /// conductor). Un punto por cada novedad menor deja de mirarse en una semana
  /// y se lleva por delante el aviso que sí importaba.
  final String? aviso;
}

/// Icono de una pestaña, con la píldora de la activa.
class _IconoNav extends StatelessWidget {
  const _IconoNav({required this.destino, required this.activo});

  final DestinoNav destino;
  final bool activo;

  /// Corta y con freno al final. Por encima de ~250 ms el cambio de pestaña
  /// deja de sentirse instantáneo y empieza a sentirse lento.
  static const Duration _duracion = Duration(milliseconds: 180);

  /// Relleno de la píldora. El mismo en reposo y activa: al cambiar de pestaña
  /// solo aparece el fondo, nada se desplaza.
  static const EdgeInsets _relleno =
      EdgeInsets.symmetric(horizontal: 18, vertical: 4);

  @override
  Widget build(BuildContext context) {
    // Fundido entre contorno y relleno. Los dos iconos miden lo mismo, así que
    // la caja no cambia de tamaño durante el cruce.
    Widget icono = AnimatedSwitcher(
      duration: _duracion,
      switchInCurve: Curves.easeOut,
      child: Icon(
        activo ? destino.iconoActivo : destino.icono,
        key: ValueKey<bool>(activo),
      ),
    );

    final aviso = destino.aviso;
    if (aviso != null) {
      icono = Stack(
        clipBehavior: Clip.none,
        children: [
          icono,
          const Positioned(top: -2, right: -3, child: _PuntoAviso()),
        ],
      );
      icono = Semantics(label: aviso, child: icono);
    }

    return AnimatedContainer(
      duration: _duracion,
      curve: Curves.easeOut,
      padding: _relleno,
      decoration: BoxDecoration(
        color: activo ? AppColors.primarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: icono,
    );
  }
}

/// Punto de aviso sobre el icono.
///
/// Lleva anillo del color de la barra: sin él, sobre la píldora naranja clara
/// de la pestaña activa el rojo se funde con el fondo y el aviso desaparece
/// justo cuando el usuario está mirando esa pestaña.
class _PuntoAviso extends StatelessWidget {
  const _PuntoAviso();

  @override
  Widget build(BuildContext context) {
    return Container(
      // 12 con anillo de 2 deja 8 de rojo: se ve de reojo y no tapa el icono.
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.danger,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
    );
  }
}

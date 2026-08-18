import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Sistema de elevación: cuatro niveles, cada uno con un dueño.
///
/// Antes las superficies se distinguían solo por un borde gris de 1 px, que a
/// pleno sol en la calle desaparece. Estas sombras van **teñidas** con la tinta
/// de marca (`AppColors.shadow`) y no con negro: sobre el fondo `background` un
/// negro puro se lee como suciedad, no como profundidad.
///
/// No se usa `elevation` de Material porque calcula sombras grises neutras y no
/// permite la sombra hacia arriba que necesita la barra anclada.
class AppElevation {
  const AppElevation._();

  /// Contenido en reposo: `MotoCard`, filas del historial.
  ///
  /// Va **junto** al borde de 1 px, no en su lugar: borde y sombra juntos es lo
  /// que separa una tarjeta del fondo en una pantalla al sol.
  static final List<BoxShadow> carta = [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.05),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  /// Elemento que agrupa decisiones: hojas modales, tarjeta de propuesta,
  /// panel de pedir del Inicio.
  static final List<BoxShadow> agrupador = [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.07),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  /// Lo que flota sobre el mapa. Más oscura a propósito: tiene que leerse igual
  /// sobre una calle blanca que sobre una zona verde.
  static final List<BoxShadow> flotante = [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 6),
    ),
  ];

  /// Barra anclada al borde inferior (acciones y navegación). La sombra va
  /// hacia **arriba**: es la única dirección en la que hay contenido del que
  /// separarse.
  static final List<BoxShadow> anclada = [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, -2),
    ),
  ];
}

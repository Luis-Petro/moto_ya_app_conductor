import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_spacing.dart';

/// Tarjeta de superficie, base visual de la app.
///
/// Lleva **borde y sombra a la vez**, no una u otra. El borde solo desaparece a
/// pleno sol, que es donde se usa esta app; la sombra sola no marca el límite
/// exacto de la tarjeta sobre un fondo casi blanco. Juntos, la tarjeta se lee
/// en las dos situaciones.
class MotoCard extends StatelessWidget {
  const MotoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.onTap,
    this.borderColor,
    this.elevacion,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  /// Nivel de `AppElevation`. Por defecto `carta` (contenido en reposo); las
  /// tarjetas que agrupan una decisión piden `agrupador`.
  final List<BoxShadow>? elevacion;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);
    return DecoratedBox(
      // La sombra va fuera del Material: dentro, el `InkWell` la recorta al
      // pintar el efecto de pulsación y parpadea en cada toque.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: elevacion ?? AppElevation.carta,
      ),
      child: Material(
        color: color ?? AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: borderColor ?? AppColors.line),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

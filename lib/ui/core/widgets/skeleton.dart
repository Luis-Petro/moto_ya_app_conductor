import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Bloque gris animado que ocupa el sitio del contenido mientras carga.
///
/// Un esqueleto con la silueta del resultado se percibe más rápido que un
/// spinner sobre pantalla vacía (umbral de Doherty): el usuario ve *qué* va a
/// llegar, y la espera deja de leerse como "se rompió".
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppSpacing.radiusSm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Silueta del panel de Inicio del conductor (estado + ganancias) mientras
/// llegan los datos, en lugar de un spinner sobre pantalla vacía.
class SkeletonInicio extends StatelessWidget {
  const SkeletonInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        Row(
          children: [
            Skeleton(width: 44, height: 44, radius: 22),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 140),
                  SizedBox(height: AppSpacing.sm),
                  Skeleton(width: 90, height: 11),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        _TarjetaFantasma(alto: 84),
        SizedBox(height: AppSpacing.lg),
        _TarjetaFantasma(alto: 148),
        SizedBox(height: AppSpacing.lg),
        _TarjetaFantasma(alto: 200),
      ],
    );
  }
}

class _TarjetaFantasma extends StatelessWidget {
  const _TarjetaFantasma({required this.alto});

  final double alto;

  @override
  Widget build(BuildContext context) {
    return Skeleton(height: alto, radius: AppSpacing.radiusMd);
  }
}

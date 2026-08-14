import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'brand.dart';

/// Bloque gris animado que ocupa el sitio del contenido mientras carga.
///
/// Un esqueleto con la silueta del resultado se percibe más rápido que un
/// spinner sobre pantalla vacía (umbral de Doherty): el usuario ve *qué* va a
/// llegar, y la espera deja de leerse como "se rompió".
///
/// **Pero eso solo vale si se ve.** Este bloque se pintaba con `AppColors.line`
/// (#E3E8EE) sobre `background` (#F7F8FA) y con la opacidad animando desde 0.4:
/// en el punto apagado quedaba en #EFF2F5, **1,06:1** de contraste contra el
/// fondo, y a opacidad plena 1,15:1. Al sol, en un celular de gama media, eso es
/// una pantalla en blanco — y así llegó el reporte. El relleno y el suelo de
/// opacidad de aquí están medidos, y hay un test que impide aclararlos.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppSpacing.radiusSm,
  });

  /// Relleno del bloque. Expuesto para que el test mida el color de verdad y no
  /// una copia del literal.
  static const Color relleno = AppColors.skeleton;

  /// Opacidad en el punto más apagado del ciclo. Es donde el contraste es peor,
  /// así que es el valor que el test comprueba.
  static const double opacidadMinima = 0.6;

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
      opacity: Tween<double>(
        begin: Skeleton.opacidadMinima,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Skeleton.relleno,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Silueta del panel de Inicio del conductor (estado + ganancias) mientras
/// llegan los datos, en lugar de un spinner sobre pantalla vacía.
///
/// La cabecera pinta el **avatar y el nombre reales** cuando la sesión ya los
/// tiene guardados: son datos que están en el primer frame y no cuestan una
/// petición, así que la pantalla se reconoce como propia antes de que llegue
/// nada de la red y solo lo que falta se ve como hueco. Sin nombre disponible se
/// queda el bloque gris: **nunca** un "Conductor" de relleno, que es inventarse
/// un dato para tapar un hueco.
class SkeletonInicio extends StatelessWidget {
  const SkeletonInicio({super.key, this.nombre, this.iniciales, this.fotoUrl});

  final String? nombre;
  final String? iniciales;
  final String? fotoUrl;

  @override
  Widget build(BuildContext context) {
    final tieneIdentidad = (nombre ?? '').trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            if (tieneIdentidad)
              InitialsAvatar(
                initials: (iniciales ?? '').trim().isEmpty
                    ? nombre!.trim().characters.first.toUpperCase()
                    : iniciales!,
                imageUrl: fotoUrl,
                radius: 22,
              )
            else
              const Skeleton(width: 44, height: 44, radius: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tieneIdentidad)
                    Text(
                      nombre!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else
                    const Skeleton(width: 140),
                  const SizedBox(height: AppSpacing.sm),
                  // La calificación y el municipio sí llegan de la red: van de
                  // hueco hasta que estén.
                  const Skeleton(width: 90, height: 11),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const _TarjetaFantasma(alto: 84),
        const SizedBox(height: AppSpacing.lg),
        const _TarjetaFantasma(alto: 148),
        const SizedBox(height: AppSpacing.lg),
        const _TarjetaFantasma(alto: 200),
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

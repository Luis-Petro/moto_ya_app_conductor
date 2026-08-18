import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'brand.dart';

/// Bloque gris animado que ocupa el sitio del contenido mientras carga.
///
/// Un esqueleto con la silueta del resultado se percibe más rápido que un
/// spinner sobre pantalla vacía (umbral de Doherty): el usuario ve *qué* va a
/// llegar, y la espera deja de leerse como "se rompió".
///
/// **Pero eso solo vale si se ve.** Este bloque se pintaba con `AppColors.line`
/// (#E3E8EE) sobre `background` (#F7F8FA): **1,06:1** de contraste contra el
/// fondo en el punto apagado del ciclo. Al sol, en un celular de gama media, eso
/// es una pantalla en blanco — y así llegó el reporte. Los dos colores de aquí
/// están medidos y `test/ui/skeleton_visible_test.dart` impide aclararlos.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppSpacing.radiusSm,
  });

  /// Los dos extremos del degradado que barre el bloque. Expuestos para que el
  /// test mida los colores de verdad y no una copia de los literales.
  static const Color relleno = AppColors.skeleton;
  static const Color brillo = AppColors.skeletonHighlight;

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  // Sin `reverse`: el brillo barre siempre en el mismo sentido, como una luz
  // que pasa. De ida y vuelta parece un péndulo y delata que no pasa nada.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Un brillo que recorre el bloque, no un parpadeo de opacidad. El parpadeo
    // hace que la pantalla entera lata a la vez y cansa; el barrido se lee como
    // "esto viene en camino".
    //
    // El brillo es un gris aclarado y no un casi-blanco (que es lo que usa
    // `app_cliente`): aquí la banda tiene que seguir viéndose sobre el fondo,
    // no desaparecer en él.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 + 2 * t, 0),
              colors: const [
                Skeleton.relleno,
                Skeleton.brillo,
                Skeleton.relleno,
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// Tarjeta fantasma: el contenedor real, con esqueletos dentro.
///
/// La tarjeta se pinta de verdad (superficie, borde, elevación) y solo el
/// contenido es fantasma. Así el salto al llegar los datos es solo de texto: si
/// el contenedor apareciera después, la lista entera se movería de sitio.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: AppElevation.carta,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
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
                      style: AppText.subtitle.copyWith(
                        fontWeight: AppText.fuerte,
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

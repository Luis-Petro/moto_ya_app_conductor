import 'package:flutter/material.dart';

import '../../../domain/models/estado_pedido.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Barra de progreso de estados del pedido (Buscando → … → Entregado).
///
/// El paso **actual** es el único que se distingue de los demás: los ya
/// cumplidos van en naranja apagado y los pendientes en gris. Antes cumplido y
/// actual se pintaban igual, y en un vistazo rápido —que es como se mira esto,
/// esperando— no se sabía en cuál se está.
class StatusStepper extends StatelessWidget {
  const StatusStepper({super.key, required this.estado});

  final EstadoPedido estado;

  @override
  Widget build(BuildContext context) {
    final pasos = EstadoPedido.pasosTracking;
    final actual = estado.indiceTracking;
    return Row(
      children: [
        for (var i = 0; i < pasos.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                // El tramo crece al llegarle el turno: el cambio se ve aunque
                // el usuario no estuviera mirando la etiqueta.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  height: i == actual ? 6 : 4,
                  decoration: BoxDecoration(
                    color: switch (i) {
                      _ when i == actual => AppColors.primary,
                      _ when i < actual => AppColors.primaryLight,
                      _ => AppColors.line,
                    },
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  pasos[i].label,
                  style: AppText.caption.copyWith(
                    color: i <= actual ? AppColors.primaryInk : AppColors.inkMuted,
                    fontWeight:
                        i == actual ? AppText.fuerte : AppText.regular,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (i < pasos.length - 1) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}

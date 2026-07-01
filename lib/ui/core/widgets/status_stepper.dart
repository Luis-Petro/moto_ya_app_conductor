import 'package:flutter/material.dart';

import '../../../domain/models/estado_pedido.dart';
import '../theme/app_colors.dart';

/// Barra de progreso de estados del pedido (Buscando → … → Entregado).
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
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= actual ? AppColors.primary : AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pasos[i].label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: i <= actual ? AppColors.primary : AppColors.inkMuted,
                    fontWeight:
                        i == actual ? FontWeight.w700 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (i < pasos.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

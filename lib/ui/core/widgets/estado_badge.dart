import 'package:flutter/material.dart';

import '../../../domain/models/estado_pedido.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Los colores de un estado de pedido, en un solo sitio.
///
/// Existía dos veces —en el historial y en el detalle— y **no coincidían**: el
/// mismo pedido entregado salía verde sobre naranja claro en una lista y verde
/// sobre verde en la otra. Ninguna de las dos daba error y las dos se veían
/// bien por separado.
///
/// La tinta es la del estado (`successInk`, `dangerInk`, `warningInk`), no el
/// color de relleno: verde sobre su propia superficie clara da 2,74:1, que al
/// sol no se lee. Lo vigila `test/ui/contraste_test.dart`.
({Color tinta, Color fondo}) coloresDeEstado(EstadoPedido estado) {
  return switch (estado) {
    EstadoPedido.entregado => (
        tinta: AppColors.successInk,
        fondo: AppColors.successSurface
      ),
    EstadoPedido.cancelado => (
        tinta: AppColors.dangerInk,
        fondo: AppColors.dangerSurface
      ),
    // "Sin conductor" no es un fracaso ni un pedido en curso: es algo que
    // espera una decisión del cliente. En azul marino se leía igual que
    // "En camino", que es justo lo contrario de lo que pasa.
    EstadoPedido.sinConductor => (
        tinta: AppColors.warningInk,
        fondo: AppColors.warningSurface
      ),
    // Todo lo que sigue en curso. Azul marino y no naranja: el naranja de la
    // marca es de las acciones, y un distintivo no se toca.
    _ => (tinta: AppColors.accent, fondo: AppColors.accentSurface),
  };
}

/// Distintivo de estado del pedido.
///
/// [grande] lo usa la cabecera del detalle, donde el estado es el titular de la
/// pantalla; sin él es el distintivo de una fila de lista.
class EstadoBadge extends StatelessWidget {
  const EstadoBadge({super.key, required this.estado, this.grande = false});

  final EstadoPedido estado;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final c = coloresDeEstado(estado);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: grande ? AppSpacing.md : AppSpacing.sm,
        vertical: grande ? AppSpacing.sm : 3,
      ),
      decoration: BoxDecoration(
        color: c.fondo,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Text(
        estado.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (grande ? AppText.subtitle : AppText.caption)
            .copyWith(color: c.tinta, fontWeight: AppText.fuerte),
      ),
    );
  }
}

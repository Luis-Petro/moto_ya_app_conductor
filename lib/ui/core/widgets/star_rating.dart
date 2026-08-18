import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Muestra una calificación en estrellas (modo lectura).
///
/// La estrella **vacía** va en gris y no en el ámbar de las llenas. Iban las
/// cinco del mismo color y a tamaño 16 —que es el de una fila de historial— una
/// vacía y una llena no se distinguían, que es lo único que una calificación
/// tiene que dejar claro. El ámbar sobre blanco da además 2,15:1, así que la
/// vacía tampoco se veía al sol.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.size = 16});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value.round();
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: filled ? AppColors.star : AppColors.starEmpty,
        );
      }),
    );
  }
}

/// Selector de calificación táctil (1–5 estrellas).
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 40,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final n = i + 1;
        final filled = n <= value;
        return Semantics(
          button: true,
          label: '$n estrella${n > 1 ? 's' : ''}',
          child: IconButton(
            iconSize: size,
            visualDensity: VisualDensity.standard,
            onPressed: () => onChanged(n),
            icon: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: filled ? AppColors.star : AppColors.starEmpty,
            ),
          ),
        );
      }),
    );
  }
}

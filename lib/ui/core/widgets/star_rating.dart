import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Muestra una calificación en estrellas (modo lectura).
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
          color: AppColors.star,
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
              color: AppColors.star,
            ),
          ),
        );
      }),
    );
  }
}

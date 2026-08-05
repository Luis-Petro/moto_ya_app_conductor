import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Botón primario de la marca con estado de carga integrado.
/// Cumple el área táctil mínima (≥48dp) por el tema de `ElevatedButton`.
///
/// Confirma la pulsación con un toque háptico: el acuse en el instante del
/// commit hace que la acción se sienta inmediata aunque la red tarde después.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  void _pulsar() {
    HapticFeedback.selectionClick();
    onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: (loading || onPressed == null) ? null : _pulsar,
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }
}

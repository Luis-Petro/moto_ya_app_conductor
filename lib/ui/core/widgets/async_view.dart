import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'mascota_animada.dart';
import 'primary_button.dart';

/// Estado de vista genérico para manejar carga/error/vacío de forma uniforme,
/// evitando que cada pantalla reinvente estos estados (anti-patrón mobile:
/// "no loading / no error state").
enum ViewStatus { idle, loading, error, ready }

/// Vista de error reutilizable con acción de reintento.
///
/// **Un fallo de red no se ve como los demás.** Con `esRed`, en lugar del icono
/// gris aparece la mascota sin conexión y un texto que nombra la causa. La
/// distinción no es decorativa: "revisa tu conexión" delante de un 409 manda a
/// alguien a reiniciar el router durante media hora por un permiso denegado.
/// Por eso el valor por defecto es `false` — quien no lo declare conserva el
/// mensaje que devolvió el backend, que es lo correcto para todo lo que no sea
/// falta de internet.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
    this.esRed = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  /// Si el fallo fue de conectividad. Se pasa desde `Failure.isNetwork`.
  final bool esRed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (esRed) ...[
              const MascotaAnimada(pose: PoseMascota.sinConexion),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Sin conexión',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'No pudimos conectarnos. Revisa tu internet e inténtalo de '
                'nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkMuted, fontSize: 15),
              ),
            ] else ...[
              Icon(icon, size: 48, color: AppColors.inkMuted),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 15),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 200,
                child: PrimaryButton(
                  label: 'Reintentar',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado vacío reutilizable.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.line),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkMuted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

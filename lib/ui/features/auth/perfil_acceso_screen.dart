import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../../router.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/encabezado.dart';

/// Selección de perfil. Esta app es para el rol CONDUCTOR ("Quiero ganar dinero").
class PerfilAccesoScreen extends StatefulWidget {
  const PerfilAccesoScreen({super.key});

  @override
  State<PerfilAccesoScreen> createState() => _PerfilAccesoScreenState();
}

class _PerfilAccesoScreenState extends State<PerfilAccesoScreen> {
  bool _conductorSeleccionado = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Se llega aquí con `go` (sin pila): la flecha va explícita para no dejar
      // una barra vacía que no lleva a ninguna parte.
      appBar: encabezado(null, onAtras: () => context.go(Rutas.login)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Cómo quieres usar Zumbeo?',
                style: AppText.display,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Puedes cambiar de perfil cuando quieras.',
                  style: AppText.body.copyWith(color: AppColors.inkMuted)),
              const SizedBox(height: AppSpacing.xl),
              _OpcionPerfil(
                icon: Icons.two_wheeler_rounded,
                titulo: 'Quiero ganar dinero',
                descripcion: 'Trabaja como conductor en tu municipio.',
                seleccionado: _conductorSeleccionado,
                onTap: () => setState(() => _conductorSeleccionado = true),
              ),
              const SizedBox(height: AppSpacing.md),
              _OpcionPerfil(
                icon: Icons.shopping_bag_outlined,
                titulo: 'Quiero pedir',
                descripcion: 'Recibe domicilios y mandados en minutos.',
                seleccionado: !_conductorSeleccionado,
                onTap: () => setState(() => _conductorSeleccionado = false),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Continuar',
                onPressed: () {
                  if (_conductorSeleccionado) {
                    context.go(Rutas.registro);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Para pedir, descarga la app Zumbeo Cliente.'),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () => context.go(Rutas.login),
                  child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionPerfil extends StatelessWidget {
  const _OpcionPerfil({
    required this.icon,
    required this.titulo,
    required this.descripcion,
    required this.seleccionado,
    required this.onTap,
  });

  final IconData icon;
  final String titulo;
  final String descripcion;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: seleccionado ? AppColors.primary : AppColors.line,
            width: seleccionado ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  seleccionado ? AppColors.primary : AppColors.primarySurface,
              child: Icon(icon,
                  color: seleccionado ? Colors.white : AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.subtitle
                          .copyWith(fontWeight: AppText.fuerte)),
                  const SizedBox(height: 2),
                  Text(descripcion, style: AppText.caption),
                ],
              ),
            ),
            Icon(
              seleccionado
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: seleccionado ? AppColors.primary : AppColors.line,
            ),
          ],
        ),
      ),
    );
  }
}

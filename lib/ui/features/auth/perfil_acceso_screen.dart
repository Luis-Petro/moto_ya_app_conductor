import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../../router.dart';

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
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Cómo quieres usar motoYa?',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text('Puedes cambiar de perfil cuando quieras.',
                  style: TextStyle(color: AppColors.inkMuted)),
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
                            Text('Para pedir, descarga la app motoYa Cliente.'),
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
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(descripcion,
                      style: const TextStyle(
                          color: AppColors.inkMuted, fontSize: 13)),
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

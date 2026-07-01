import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../di/locator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/primary_button.dart';
import 'perfil_view_model.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PerfilViewModel(
        locator<UsuarioRepository>(),
        locator<ConductorRepository>(),
        locator<AuthRepository>(),
      )..cargar(),
      child: const _PerfilView(),
    );
  }
}

class _PerfilView extends StatefulWidget {
  const _PerfilView();

  @override
  State<_PerfilView> createState() => _PerfilViewState();
}

class _PerfilViewState extends State<_PerfilView> {
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _telefono.dispose();
    super.dispose();
  }

  void _sincronizar(PerfilViewModel vm) {
    _nombre.text = vm.usuario?.nombre ?? '';
    _email.text = vm.usuario?.email ?? '';
    _telefono.text = vm.usuario?.telefono ?? '';
  }

  Future<void> _guardar(PerfilViewModel vm) async {
    final ok = await vm.guardar(
      nombre: _nombre.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      telefono: _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Perfil actualizado' : (vm.error ?? 'Error'))),
    );
  }

  Future<void> _confirmarSalir(PerfilViewModel vm) async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (salir == true) await vm.cerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PerfilViewModel>();
    if (!vm.editando && !vm.cargando) _sincronizar(vm);
    final conductor = vm.conductor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          if (!vm.cargando && vm.usuario != null)
            IconButton(
              icon: Icon(vm.editando ? Icons.close : Icons.edit_outlined),
              onPressed: () => vm.activarEdicion(!vm.editando),
            ),
        ],
      ),
      body: SafeArea(
        child: vm.cargando
            ? const Center(child: CircularProgressIndicator())
            : vm.usuario == null
                ? ErrorRetry(
                    message: vm.error ?? 'No pudimos cargar tu perfil',
                    onRetry: vm.cargar)
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      Center(
                          child: InitialsAvatar(
                              initials: vm.usuario!.iniciales, radius: 40)),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: Text(vm.usuario!.nombre,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _Campo(
                          label: 'Nombre',
                          controller: _nombre,
                          editable: vm.editando,
                          icon: Icons.person_outline),
                      const SizedBox(height: AppSpacing.md),
                      _Campo(
                          label: 'Correo',
                          controller: _email,
                          editable: vm.editando,
                          icon: Icons.mail_outline,
                          keyboard: TextInputType.emailAddress),
                      const SizedBox(height: AppSpacing.md),
                      _Campo(
                          label: 'Celular',
                          controller: _telefono,
                          editable: vm.editando,
                          icon: Icons.phone_outlined,
                          keyboard: TextInputType.phone),
                      if (conductor != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const Text('VEHÍCULO Y DOCUMENTOS',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkMuted,
                                letterSpacing: 0.4)),
                        const SizedBox(height: AppSpacing.sm),
                        MotoCard(
                          child: Column(
                            children: [
                              _InfoFila(
                                  icon: Icons.two_wheeler_rounded,
                                  label: 'Vehículo',
                                  valor: conductor.vehiculo ?? '—'),
                              const Divider(height: AppSpacing.lg),
                              _InfoFila(
                                  icon: Icons.pin_outlined,
                                  label: 'Placa',
                                  valor: conductor.placa ?? '—'),
                              const Divider(height: AppSpacing.lg),
                              _InfoFila(
                                icon: Icons.description_outlined,
                                label: 'Documentos',
                                valor: conductor.tieneDocumentos
                                    ? 'Cargados'
                                    : 'Pendientes',
                                valorColor: conductor.tieneDocumentos
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      if (vm.editando)
                        PrimaryButton(
                          label: 'Guardar cambios',
                          loading: vm.guardando,
                          onPressed: () => _guardar(vm),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () => _confirmarSalir(vm),
                          icon: const Icon(Icons.logout, color: AppColors.danger),
                          label: const Text('Cerrar sesión',
                              style: TextStyle(color: AppColors.danger)),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      const Center(
                        child: Text('Hecho en Colombia 🇨🇴',
                            style: TextStyle(
                                color: AppColors.inkMuted, fontSize: 12)),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _InfoFila extends StatelessWidget {
  const _InfoFila({
    required this.icon,
    required this.label,
    required this.valor,
    this.valorColor,
  });
  final IconData icon;
  final String label;
  final String valor;
  final Color? valorColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.inkMuted),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: const TextStyle(color: AppColors.inkMuted)),
        const Spacer(),
        Text(valor,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: valorColor ?? AppColors.ink)),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.label,
    required this.controller,
    required this.editable,
    required this.icon,
    this.keyboard,
  });

  final String label;
  final TextEditingController controller;
  final bool editable;
  final IconData icon;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
                letterSpacing: 0.4)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: editable,
          keyboardType: keyboard,
          decoration: InputDecoration(prefixIcon: Icon(icon)),
        ),
      ],
    );
  }
}

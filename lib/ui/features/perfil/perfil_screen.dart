import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../di/locator.dart';
import '../../core/tab_activa.dart';
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
        locator<TabActiva>(),
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
  final _telefono = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    super.dispose();
  }

  void _sincronizar(PerfilViewModel vm) {
    _nombre.text = vm.usuario?.nombre ?? '';
    _telefono.text = vm.usuario?.telefono ?? '';
  }

  void _aviso(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _cambiarFoto(PerfilViewModel vm) async {
    final ok = await vm.cambiarFoto();
    if (ok == null || !mounted) return;
    _aviso(ok ? 'Foto actualizada' : (vm.error ?? 'No se pudo subir la foto'));
  }

  /// Flujo de cambio de correo en dos pasos (código al correo nuevo).
  Future<void> _cambiarCorreo(PerfilViewModel vm) async {
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    var paso = 1;
    String? errorLocal;
    var ocupado = false;
    var exito = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          Future<void> enviar() async {
            final email = emailCtrl.text.trim();
            if (email.isEmpty) {
              setSheet(() => errorLocal = 'Escribe un correo');
              return;
            }
            setSheet(() {
              ocupado = true;
              errorLocal = null;
            });
            final err = await vm.solicitarCambioCorreo(email);
            setSheet(() {
              ocupado = false;
              errorLocal = err;
              if (err == null) paso = 2;
            });
          }

          Future<void> confirmar() async {
            setSheet(() {
              ocupado = true;
              errorLocal = null;
            });
            final err = await vm.confirmarCambioCorreo(codeCtrl.text.trim());
            if (err == null) {
              exito = true;
              if (ctx.mounted) Navigator.pop(ctx);
              return;
            }
            setSheet(() {
              ocupado = false;
              errorLocal = err;
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              top: AppSpacing.xl,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paso == 1 ? 'Cambiar correo' : 'Verifica tu correo',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  paso == 1
                      ? 'Te enviaremos un código al correo nuevo para confirmar que es tuyo.'
                      : 'Escribe el código que enviamos a ${emailCtrl.text.trim()}.',
                  style:
                      const TextStyle(color: AppColors.inkMuted, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (paso == 1)
                  TextField(
                    controller: emailCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo nuevo',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  )
                else
                  TextField(
                    controller: codeCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Código',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                if (errorLocal != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(errorLocal!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: paso == 1 ? 'Enviar código' : 'Confirmar',
                  loading: ocupado,
                  onPressed: paso == 1 ? enviar : confirmar,
                ),
                if (paso == 2)
                  TextButton(
                    onPressed: ocupado ? null : enviar,
                    child: const Text('Reenviar código'),
                  ),
              ],
            ),
          );
        });
      },
    );

    emailCtrl.dispose();
    codeCtrl.dispose();
    if (exito && mounted) _aviso('Correo actualizado');
  }

  Future<void> _confirmarSalir(PerfilViewModel vm) async {
    // useRootNavigator: false — dentro de un tab del StatefulShellRoute el
    // navigator raíz pinta un velo negro sobre el shell (pantalla en negro).
    final salir = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
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
    if (!vm.cargando) _sincronizar(vm);
    final conductor = vm.conductor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          // Cerrar sesión SIEMPRE accesible: aunque el perfil no cargue (401 o
          // error de red), el conductor debe poder salir y no quedar atrapado.
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _confirmarSalir(vm),
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
                : RefreshIndicator(
                    onRefresh: vm.cargar,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap:
                                vm.subiendoFoto ? null : () => _cambiarFoto(vm),
                            child: _FotoPerfil(
                              fotoUrl: conductor?.fotoUrl,
                              iniciales: vm.usuario!.iniciales,
                              cargando: vm.subiendoFoto,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton.icon(
                            onPressed:
                                vm.subiendoFoto ? null : () => _cambiarFoto(vm),
                            icon: const Icon(Icons.photo_camera_outlined,
                                size: 16),
                            label: Text(conductor?.fotoUrl != null
                                ? 'Cambiar foto'
                                : 'Agregar foto'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Center(
                          child: Text(vm.usuario!.nombre,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                        if (conductor?.calificacion != null) ...[
                          const SizedBox(height: 4),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 2),
                                Text(
                                  conductor!.calificacion!.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                if (conductor.tasaAceptacion != null)
                                  Text(
                                    '  ·  ${conductor.tasaAceptacion!.toStringAsFixed(0)}% aceptación',
                                    style: const TextStyle(
                                        color: AppColors.inkMuted,
                                        fontSize: 13),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),

                        // Nombre y celular: identidad verificada, no editables.
                        _Campo(
                            label: 'Nombre',
                            controller: _nombre,
                            editable: false,
                            icon: Icons.person_outline),
                        const SizedBox(height: AppSpacing.md),
                        _Campo(
                            label: 'Celular',
                            controller: _telefono,
                            editable: false,
                            icon: Icons.phone_outlined,
                            keyboard: TextInputType.phone),
                        const SizedBox(height: AppSpacing.md),

                        // Correo: cambio verificado (nunca edición directa).
                        MotoCard(
                          child: _CorreoTile(
                            email: vm.usuario!.email,
                            onCambiar: () => _cambiarCorreo(vm),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'El nombre y el celular no se pueden cambiar: son tu identidad verificada. Si necesitas corregirlos, contáctanos.',
                          style: TextStyle(
                              color: AppColors.inkMuted, fontSize: 12),
                        ),

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
                        OutlinedButton.icon(
                          onPressed: () => _confirmarSalir(vm),
                          icon: const Icon(Icons.logout,
                              color: AppColors.danger),
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
      ),
    );
  }
}

/// Avatar de perfil del conductor: foto real (si existe) o iniciales, con una
/// insignia de cámara y overlay de carga mientras se sube.
class _FotoPerfil extends StatelessWidget {
  const _FotoPerfil({
    required this.iniciales,
    this.fotoUrl,
    this.cargando = false,
  });
  final String iniciales;
  final String? fotoUrl;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (fotoUrl != null && fotoUrl!.isNotEmpty)
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primarySurface,
            backgroundImage: NetworkImage(fotoUrl!),
          )
        else
          InitialsAvatar(initials: iniciales, radius: 40),
        if (cargando)
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.black45,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
          ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.photo_camera, size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Fila de correo: muestra el actual y ofrece cambiarlo por el flujo verificado.
class _CorreoTile extends StatelessWidget {
  const _CorreoTile({required this.onCambiar, this.email});

  final String? email;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    final tiene = (email ?? '').isNotEmpty;
    return Row(
      children: [
        const Icon(Icons.mail_outline, color: AppColors.inkMuted, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CORREO',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted,
                      letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(tiene ? email! : 'Sin correo',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tiene ? AppColors.ink : AppColors.inkMuted)),
            ],
          ),
        ),
        TextButton(
          onPressed: onCambiar,
          child: Text(tiene ? 'Cambiar' : 'Agregar'),
        ),
      ],
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

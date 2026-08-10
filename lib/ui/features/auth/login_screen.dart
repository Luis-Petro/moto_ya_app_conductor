import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../di/locator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/phone_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../router.dart';
import 'otp_screen.dart';
import 'login_view_model.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(locator<AuthRepository>()),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _verPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final vm = context.read<LoginViewModel>();
    final ok = await vm.loginEmail(_email.text, _password.text);
    if (!mounted) return;
    if (ok) {
      context.go(Rutas.alta);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'No pudimos iniciar sesión')),
      );
    }
  }

  /// Recuperación de contraseña. El aviso final es **neutro** a propósito: el
  /// backend responde igual exista o no la cuenta, y decirle a un desconocido
  /// si un correo está registrado sería filtrar quién usa la app.
  Future<void> _olvideMiPassword() async {
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecuperarSheet(inicial: _email.text.trim()),
    );
    if (email == null || !mounted) return;
    final vm = context.read<LoginViewModel>();
    final err = await vm.recuperarPassword(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ??
            'Si ese correo tiene una cuenta, te enviamos un enlace para '
                'crear una contraseña nueva. Revisa tu bandeja.'),
      ),
    );
  }

  Future<void> _ingresarConCelular() async {
    final telefono = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CelularSheet(),
    );
    if (telefono == null || !mounted) return;
    final vm = context.read<LoginViewModel>();
    final ok = await vm.solicitarOtp(telefono);
    if (!mounted) return;
    if (ok) {
      context.push(Rutas.otp, extra: OtpArgs(telefono: telefono));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'No pudimos enviar el código')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    // Layout que cabe en pantalla sin scroll: el contenido se ajusta a la
    // altura visible y solo se desplaza si el teclado reduce el espacio.
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      const Center(child: BrandMascota(height: 130)),
                      const SizedBox(height: AppSpacing.md),
                      const Text('Hola de nuevo 👋',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: AppSpacing.xs),
                      const Text('Ingresa para recibir pedidos en motoYa.',
                          style: TextStyle(color: AppColors.inkMuted)),
                      const SizedBox(height: AppSpacing.lg),

                      const _Label('Correo'),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'tucorreo@ejemplo.com',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _Label('Contraseña'),
                      TextField(
                        controller: _password,
                        obscureText: !_verPassword,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_verPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _verPassword = !_verPassword),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed:
                              vm.recuperandoPassword ? null : _olvideMiPassword,
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PrimaryButton(
                          label: 'Ingresar',
                          loading: vm.cargando,
                          onPressed: _login),

                      // El código por mensaje queda como alternativa, no como
                      // vía principal: cada intento cuesta un SMS y la mayoría
                      // de los conductores ya entran con su correo.
                      const SizedBox(height: AppSpacing.lg),
                      const _Divisor(),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: _ingresarConCelular,
                        icon: const Icon(Icons.sms_outlined, size: 18),
                        label: const Text('Ingresar con código por mensaje'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.inkMuted,
                        ),
                      ),

                      const Spacer(),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go(Rutas.acceso),
                          child: const Text('¿No tienes cuenta? Regístrate'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Hoja inferior para capturar el correo de recuperación.
class _RecuperarSheet extends StatefulWidget {
  const _RecuperarSheet({required this.inicial});
  final String inicial;
  @override
  State<_RecuperarSheet> createState() => _RecuperarSheetState();
}

class _RecuperarSheetState extends State<_RecuperarSheet> {
  late final _email = TextEditingController(text: widget.inicial);
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _enviar() {
    final email = _email.text.trim();
    // Validación mínima local: solo para evitar el viaje con un campo vacío o
    // sin arroba; la validación real es del backend.
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Escribe un correo válido');
      return;
    }
    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recuperar contraseña',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Te enviamos un enlace al correo de tu cuenta para crear una '
            'contraseña nueva.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'tucorreo@ejemplo.com',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(_error!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: 'Enviar enlace', onPressed: _enviar),
        ],
      ),
    );
  }
}

class _Divisor extends StatelessWidget {
  const _Divisor();
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('¿sin contraseña a la mano?',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 12)),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.inkMuted,
              letterSpacing: 0.4)),
    );
  }
}

/// Hoja inferior para capturar el celular y enviar el código de acceso.
class _CelularSheet extends StatefulWidget {
  const _CelularSheet();
  @override
  State<_CelularSheet> createState() => _CelularSheetState();
}

class _CelularSheetState extends State<_CelularSheet> {
  final _telefono = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _telefono.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!telefonoCoValido(_telefono.text)) {
      setState(() => _error = 'Celular inválido');
      return;
    }
    Navigator.of(context).pop(normalizarTelefonoCo(_telefono.text));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ingresa con tu celular',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.lg),
          PhoneField(controller: _telefono),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(_error!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: 'Enviar código', onPressed: _enviar),
        ],
      ),
    );
  }
}

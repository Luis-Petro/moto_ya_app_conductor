import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../di/locator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/phone_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../router.dart';
import 'otp_screen.dart';
import 'registro_view_model.dart';

class RegistroScreen extends StatelessWidget {
  const RegistroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegistroViewModel(locator<AuthRepository>()),
      child: const _RegistroView(),
    );
  }
}

class _RegistroView extends StatefulWidget {
  const _RegistroView();

  @override
  State<_RegistroView> createState() => _RegistroViewState();
}

class _RegistroViewState extends State<_RegistroView> {
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  bool _aceptaTerminos = false;
  String? _errorNombre;
  String? _errorTelefono;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _formularioValido =>
      _nombre.text.trim().length >= 3 &&
      telefonoCoValido(_telefono.text) &&
      _aceptaTerminos;

  Future<void> _continuar() async {
    setState(() {
      _errorNombre =
          _nombre.text.trim().length < 3 ? 'Ingresa tu nombre completo' : null;
      _errorTelefono =
          telefonoCoValido(_telefono.text) ? null : 'Celular inválido';
    });
    if (!_formularioValido) return;

    final vm = context.read<RegistroViewModel>();
    final telefono = normalizarTelefonoCo(_telefono.text);
    final ok = await vm.solicitarCodigo(telefono);
    if (!mounted) return;
    if (ok) {
      context.push(
        Rutas.otp,
        extra: OtpArgs(
          telefono: telefono,
          nombre: _nombre.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'No pudimos enviar el código')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RegistroViewModel>();
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const Text('Crea tu cuenta',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: AppSpacing.xs),
            const Text('Como conductor · gana con los domicilios de tu municipio',
                style: TextStyle(color: AppColors.inkMuted)),
            const SizedBox(height: AppSpacing.xl),
            const _Label('Nombre completo'),
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Jhon Restrepo',
                prefixIcon: const Icon(Icons.person_outline),
                errorText: _errorNombre,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PhoneField(controller: _telefono),
            if (_errorTelefono != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(_errorTelefono!,
                    style:
                        const TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            const SizedBox(height: AppSpacing.lg),
            const _Label('Correo (opcional)'),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'tucorreo@ejemplo.com',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            CheckboxListTile(
              value: _aceptaTerminos,
              onChanged: (v) => setState(() => _aceptaTerminos = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              title: const Text(
                'Acepto los Términos y la Política de privacidad de motoYa.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Crear cuenta',
              loading: vm.enviando,
              onPressed: _formularioValido ? _continuar : null,
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

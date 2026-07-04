import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _cedula = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _verPassword = false;
  bool _aceptaTerminos = false;

  String? _errNombres;
  String? _errApellidos;
  String? _errCedula;
  String? _errTelefono;
  String? _errEmail;
  String? _errPassword;

  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    _cedula.dispose();
    _telefono.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _emailValido(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

  bool _validar() {
    setState(() {
      _errNombres = _nombres.text.trim().length < 2 ? 'Ingresa tus nombres' : null;
      _errApellidos =
          _apellidos.text.trim().length < 2 ? 'Ingresa tus apellidos' : null;
      _errCedula =
          _cedula.text.trim().length < 5 ? 'Ingresa tu número de cédula' : null;
      _errTelefono = telefonoCoValido(_telefono.text) ? null : 'Celular inválido';
      _errEmail = _emailValido(_email.text) ? null : 'Correo inválido';
      _errPassword =
          _password.text.length < 6 ? 'Mínimo 6 caracteres' : null;
    });
    return _errNombres == null &&
        _errApellidos == null &&
        _errCedula == null &&
        _errTelefono == null &&
        _errEmail == null &&
        _errPassword == null &&
        _aceptaTerminos;
  }

  Future<void> _continuar() async {
    if (!_validar()) {
      if (!_aceptaTerminos) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Debes aceptar los Términos para continuar')));
      }
      return;
    }
    final vm = context.read<RegistroViewModel>();
    final telefono = normalizarTelefonoCo(_telefono.text);
    final ok = await vm.registrar(
      nombres: _nombres.text.trim(),
      apellidos: _apellidos.text.trim(),
      cedula: _cedula.text.trim(),
      telefonoE164: telefono,
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      // Cuenta creada: validar el teléfono con el código antes de operar.
      context.push(
        Rutas.otp,
        extra: OtpArgs(
          telefono: telefono,
          nombre: '${_nombres.text.trim()} ${_apellidos.text.trim()}'.trim(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'No pudimos crear tu cuenta')),
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
            const _Label('Nombres'),
            TextField(
              controller: _nombres,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Jhon Alberto',
                prefixIcon: const Icon(Icons.person_outline),
                errorText: _errNombres,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _Label('Apellidos'),
            TextField(
              controller: _apellidos,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Restrepo Gómez',
                prefixIcon: const Icon(Icons.badge_outlined),
                errorText: _errApellidos,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _Label('Cédula'),
            TextField(
              controller: _cedula,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '1000123456',
                prefixIcon: const Icon(Icons.credit_card_outlined),
                errorText: _errCedula,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _Label('Celular'),
            PhoneField(controller: _telefono),
            if (_errTelefono != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(_errTelefono!,
                    style:
                        const TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            const SizedBox(height: AppSpacing.md),
            const _Label('Correo'),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'tucorreo@ejemplo.com',
                prefixIcon: const Icon(Icons.mail_outline),
                errorText: _errEmail,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _Label('Contraseña'),
            TextField(
              controller: _password,
              obscureText: !_verPassword,
              decoration: InputDecoration(
                hintText: 'Mínimo 6 caracteres',
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: _errPassword,
                suffixIcon: IconButton(
                  icon: Icon(_verPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _verPassword = !_verPassword),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Crear cuenta',
              loading: vm.enviando,
              onPressed: _continuar,
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

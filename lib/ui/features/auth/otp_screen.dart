import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../di/locator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../../router.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/encabezado.dart';
import 'otp_view_model.dart';

/// Argumentos de la pantalla de verificación OTP.
class OtpArgs {
  const OtpArgs({required this.telefono, this.nombre});
  final String telefono;
  final String? nombre;
}

class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key, required this.args});
  final OtpArgs args;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OtpViewModel(
        locator<AuthRepository>(),
        args.telefono,
        args.nombre,
      ),
      child: _OtpView(telefono: args.telefono),
    );
  }
}

class _OtpView extends StatefulWidget {
  const _OtpView({required this.telefono});
  final String telefono;

  @override
  State<_OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<_OtpView> {
  static const _largo = 4;
  final _controller = TextEditingController();
  Timer? _timer;
  int _segundos = 42;

  /// Hay una verificación en vuelo.
  ///
  /// Sin esta guarda el código se verifica **dos veces**: el autocompletado del
  /// SMS llena las cuatro cajas y dispara `onChanged`, y acto seguido la persona
  /// pulsa «Verificar» sobre unas cajas que ya se ven llenas. El código es de un
  /// solo uso en el backend (`OtpService` lo borra al acertar), así que la
  /// primera llamada acierta y la segunda recibe un 401 — y lo que queda en
  /// pantalla es el acuse de la segunda: «el código no es correcto» sobre un
  /// código que sí lo era.
  bool _enVuelo = false;

  @override
  void initState() {
    super.initState();
    _iniciarCuentaRegresiva();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _iniciarCuentaRegresiva() {
    _timer?.cancel();
    setState(() => _segundos = 42);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundos <= 0) {
        t.cancel();
      } else {
        setState(() => _segundos--);
      }
    });
  }

  Future<void> _verificar() async {
    if (_enVuelo) return;
    _enVuelo = true;
    final vm = context.read<OtpViewModel>();
    // **El router se toma ANTES del await y se navega con él, no con el
    // `context`.** Guardar la sesión notifica al `refreshListenable` del router,
    // y su redirect saca esta ruta de las de acceso: la pantalla se desmonta
    // mientras la verificación está en vuelo, y con `if (!mounted) return` la
    // navegación de abajo se pierde.
    final router = GoRouter.of(context);
    try {
      final ok = await vm.verificar(_controller.text);
      if (!ok) {
        // Limpiar las cajas para reintentar de una: el error queda visible
        // bajo el código (más claro que solo un snackbar).
        if (mounted) setState(() => _controller.clear());
        return;
      }
      // Nuevo conductor: pasa por el alta de perfil (que redirige a Inicio si
      // ya estuviera completo).
      router.go(Rutas.alta);
    } finally {
      _enVuelo = false;
    }
  }

  Future<void> _reenviar() async {
    final vm = context.read<OtpViewModel>();
    final ok = await vm.reenviar();
    if (!mounted) return;
    if (ok) _iniciarCuentaRegresiva();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Código reenviado' : 'No pudimos reenviar')),
    );
  }

  String get _telefonoVisible {
    final t = widget.telefono;
    return t.startsWith('+57') ? '+57 ${t.substring(3)}' : t;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OtpViewModel>();
    final completo = _controller.text.length == _largo;
    return Scaffold(
      // Retroceso explícito: a esta pantalla se llega desde el registro y desde
      // el login por celular, y `AppBar()` sola solo pinta la flecha si hay algo
      // que desapilar. Quien se equivocó de número quedaba encerrado.
      appBar: encabezado(null, onAtras: () => context.go(Rutas.login)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primarySurface,
                child: Icon(Icons.sms_outlined, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Verifica tu celular', style: AppText.display),
              const SizedBox(height: AppSpacing.sm),
              Text('Enviamos un código de 4 dígitos al\n$_telefonoVisible',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.inkMuted)),
              const SizedBox(height: AppSpacing.xl),
              _CajasCodigo(controller: _controller, largo: _largo, onChanged: () {
                setState(() {});
                if (_controller.text.length == _largo) _verificar();
              }),
              if (vm.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                // **El motivo lo dice el servidor.** Con un texto fijo, un 401
                // por código vencido, un 429 por código quemado tras cinco
                // intentos y un 502 porque ningún canal pudo enviar se veían
                // los tres iguales. El peor es el 429: el código ya no existe y
                // la pantalla invitaba a «revisarlo e intentarlo de nuevo», así
                // que la salida obvia —volver a teclear el mismo— no podía
                // funcionar nunca.
                Text(
                  vm.error ??
                      'El código no es correcto. Revísalo e inténtalo de nuevo.',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(
                      color: AppColors.dangerInk,
                      fontWeight: AppText.medio),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (_segundos > 0)
                Text(
                  'Reenviar código en 0:${_segundos.toString().padLeft(2, '0')}',
                  style: AppText.body.copyWith(color: AppColors.inkMuted),
                )
              else
                TextButton(
                  onPressed: vm.reenviando ? null : _reenviar,
                  child: const Text('Reenviar código'),
                ),
              const Spacer(),
              PrimaryButton(
                label: 'Verificar',
                loading: vm.verificando,
                onPressed: completo ? _verificar : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4 cajas de dígito alimentadas por un único TextField (accesible y simple).
class _CajasCodigo extends StatelessWidget {
  const _CajasCodigo({
    required this.controller,
    required this.largo,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int largo;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Cajas visibles
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(largo, (i) {
            final texto = controller.text;
            final lleno = i < texto.length;
            final activo = i == texto.length;
            return Container(
              width: 56,
              height: 64,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                  color: activo || lleno ? AppColors.primary : AppColors.line,
                  width: activo ? 1.8 : 1,
                ),
              ),
              // `money` por las figuras tabulares: son cuatro dígitos en cajas
              // de ancho fijo y con figuras proporcionales el 1 quedaba
              // descentrado en su caja y los demás no.
              child: Text(lleno ? texto[i] : '', style: AppText.money),
            );
          }),
        ),
        // Campo invisible que captura la entrada
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: largo,
              showCursor: false,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
        ),
      ],
    );
  }
}

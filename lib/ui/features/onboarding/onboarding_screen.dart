import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../../router.dart';
import '../splash/splash_screen.dart';

class _Slide {
  const _Slide(this.imagen, this.titulo, this.descripcion);
  final String imagen;
  final String titulo;
  final String descripcion;
}

/// Carrusel de onboarding del conductor (primera apertura).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _pagina = 0;

  static const _slides = [
    _Slide('assets/images/onboarding_1.png', 'Gana dinero en tu municipio',
        'Recibe pedidos cercanos y decide cuándo conectarte. Sin suscripción inicial.'),
    _Slide('assets/images/onboarding_2.png', 'Tú pones tu tarifa',
        'Acepta la tarifa sugerida o propón la tuya. Ves tu ganancia neta antes de aceptar.'),
    _Slide('assets/images/onboarding_3.png', 'Cobra y liquida fácil',
        'Solo pagas el 15% de comisión sobre el servicio. Liquídala con Nequi o Bre-B.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finalizar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SplashScreen.onboardingVistoKey, true);
    if (!mounted) return;
    context.go(Rutas.acceso);
  }

  void _siguiente() {
    if (_pagina < _slides.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _finalizar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final esUltima = _pagina == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finalizar, child: const Text('Saltar')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Tamaño uniforme para todas las imágenes: se escalan
                        // dentro de un cuadro fijo sin recortarse (BoxFit.contain).
                        SizedBox(
                          height: 280,
                          width: double.infinity,
                          child: Image.asset(s.imagen, fit: BoxFit.contain),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(s.titulo,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                        const SizedBox(height: AppSpacing.md),
                        Text(s.descripcion,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.inkMuted,
                                fontSize: 15,
                                height: 1.4)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final activo = i == _pagina;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 6,
                  width: activo ? 22 : 6,
                  decoration: BoxDecoration(
                    color: activo ? AppColors.primary : AppColors.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: PrimaryButton(
                label: esUltima ? 'Comenzar' : 'Siguiente',
                icon: esUltima ? null : Icons.arrow_forward_rounded,
                onPressed: _siguiente,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

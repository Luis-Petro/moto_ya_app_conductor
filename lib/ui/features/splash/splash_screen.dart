import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../di/locator.dart';
import '../../core/widgets/brand.dart';
import '../../router.dart';

/// Splash de marca. Resuelve la sesión y el perfil de conductor para decidir el
/// destino inicial: Inicio (perfil completo), Alta (autenticado sin perfil),
/// u onboarding/login (sin sesión).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const onboardingVistoKey = 'onboarding_visto';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _resolver();
  }

  Future<void> _resolver() async {
    final auth = locator<AuthRepository>();
    await Future.wait([
      auth.cargarSesion(),
      Future.delayed(const Duration(milliseconds: 700)),
    ]);
    if (!mounted) return;

    if (auth.estaAutenticado) {
      // Resuelve el perfil de conductor: con perfil completo va a Inicio; si no,
      // al alta. Un fallo de red también manda al alta (allí puede reintentar).
      final conductores = locator<ConductorRepository>();
      await conductores.cargar(forzar: true);
      if (!mounted) return;
      context.go(conductores.perfilCompleto ? Rutas.inicio : Rutas.alta);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final visto = prefs.getBool(SplashScreen.onboardingVistoKey) ?? false;
    if (!mounted) return;
    context.go(visto ? Rutas.login : Rutas.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrandLockup(width: 240),
            SizedBox(height: 12),
            Text('Conductor',
                style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2)),
            SizedBox(height: 28),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}

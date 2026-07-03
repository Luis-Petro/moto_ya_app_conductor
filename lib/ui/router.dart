import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/auth_repository.dart';
import '../domain/models/pedido.dart';
import 'features/alta_conductor/alta_conductor_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/perfil_acceso_screen.dart';
import 'features/auth/registro_screen.dart';
import 'features/billetera/billetera_screen.dart';
import 'features/historial/historial_screen.dart';
import 'features/inicio/inicio_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/pedido_activo/pedido_activo_screen.dart';
import 'features/pedido_detalle/pedido_detalle_screen.dart';
import 'features/pedido_entrante/pedido_entrante_screen.dart';
import 'features/perfil/perfil_screen.dart';
import 'features/shell/conductor_shell.dart';
import 'features/splash/splash_screen.dart';

/// Rutas de la app conductor.
abstract class Rutas {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const acceso = '/acceso';
  static const registro = '/registro';
  static const otp = '/otp';
  static const login = '/login';
  static const alta = '/alta';
  static const inicio = '/inicio';
  static const billetera = '/billetera';
  static const historial = '/historial';
  static const perfil = '/perfil';

  static String pedidoEntrante(int pedidoId) => '/pedido/$pedidoId/entrante';
  static String pedidoActivo(int pedidoId) => '/pedido/$pedidoId/activo';
  static String pedidoDetalle(int pedidoId) => '/pedido/$pedidoId/detalle';
}

/// Rutas públicas (de acceso) en las que un usuario autenticado no debe estar.
const _rutasAcceso = {
  Rutas.splash,
  Rutas.onboarding,
  Rutas.acceso,
  Rutas.registro,
  Rutas.otp,
  Rutas.login,
};

GoRouter crearRouter(AuthRepository auth) {
  final rootKey = GlobalKey<NavigatorState>();
  final shellKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: Rutas.splash,
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!auth.inicializado) {
        return loc == Rutas.splash ? null : Rutas.splash;
      }
      final enAcceso = _rutasAcceso.contains(loc);
      if (auth.estaAutenticado) {
        // El splash/alta deciden el destino según el perfil de conductor.
        if (enAcceso && loc != Rutas.splash) return Rutas.inicio;
        return null;
      }
      if (!enAcceso) return Rutas.login;
      return null;
    },
    routes: [
      GoRoute(path: Rutas.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: Rutas.onboarding, builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: Rutas.acceso, builder: (_, __) => const PerfilAccesoScreen()),
      GoRoute(path: Rutas.registro, builder: (_, __) => const RegistroScreen()),
      GoRoute(
        path: Rutas.otp,
        // Si el router se refresca y pierde el extra, volver al acceso en vez
        // de reventar el build con un cast nulo (pantalla en blanco).
        redirect: (_, state) => state.extra is OtpArgs ? null : Rutas.acceso,
        builder: (_, state) => OtpScreen(args: state.extra as OtpArgs),
      ),
      GoRoute(path: Rutas.login, builder: (_, __) => const LoginScreen()),

      // Alta del perfil de conductor (post-login, antes de operar).
      GoRoute(
        path: Rutas.alta,
        parentNavigatorKey: rootKey,
        builder: (_, __) => const AltaConductorScreen(),
      ),

      // Tabs con estado preservado (Inicio · Billetera · Historial · Perfil).
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ConductorShell(shell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: shellKey,
            routes: [
              GoRoute(path: Rutas.inicio, builder: (_, __) => const InicioScreen()),
            ],
          ),
          StatefulShellBranch(routes: [
            GoRoute(
                path: Rutas.billetera,
                builder: (_, __) => const BilleteraScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: Rutas.historial,
                builder: (_, __) => const HistorialScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: Rutas.perfil, builder: (_, __) => const PerfilScreen()),
          ]),
        ],
      ),

      // Flujos a pantalla completa (sobre el navigator raíz).
      GoRoute(
        path: '/pedido/:id/entrante',
        parentNavigatorKey: rootKey,
        builder: (_, state) =>
            PedidoEntranteScreen(pedidoId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/pedido/:id/activo',
        parentNavigatorKey: rootKey,
        builder: (_, state) =>
            PedidoActivoScreen(pedidoId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/pedido/:id/detalle',
        parentNavigatorKey: rootKey,
        builder: (_, state) => PedidoDetalleScreen(
          pedidoId: int.parse(state.pathParameters['id']!),
          inicial: state.extra is Pedido ? state.extra as Pedido : null,
        ),
      ),
    ],
  );
}

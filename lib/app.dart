import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/repositories/auth_repository.dart';
import 'data/services/push_service.dart';
import 'di/locator.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/router.dart';

/// Raíz de la app motoYa Conductor. Configura tema, localización en español,
/// router con guardas y la navegación por notificaciones push.
class MotoYaConductorApp extends StatefulWidget {
  const MotoYaConductorApp({super.key});

  @override
  State<MotoYaConductorApp> createState() => _MotoYaConductorAppState();
}

class _MotoYaConductorAppState extends State<MotoYaConductorApp> {
  late final AuthRepository _auth = locator<AuthRepository>();
  late final GoRouter _router = crearRouter(_auth);

  @override
  void initState() {
    super.initState();
    _configurarPush();
  }

  Future<void> _configurarPush() async {
    final push = locator<PushService>();
    void abrir(PushMensaje m) {
      if (!_auth.estaAutenticado) return;
      // Bloqueo por deuda → billetera.
      if (m.tipo == 'BLOQUEO_DEUDA' || m.tipo == 'BLOQUEADO_POR_DEUDA') {
        _router.go(Rutas.billetera);
        return;
      }
      if (m.pedidoId == null) return;
      // Pedido nuevo → tarjeta de oferta; aceptación/avances → pedido activo.
      if (m.tipo == 'PEDIDO_NUEVO') {
        _router.push(Rutas.pedidoEntrante(m.pedidoId!));
      } else {
        _router.push(Rutas.pedidoActivo(m.pedidoId!));
      }
    }

    push.onMensajeAbierto = abrir;
    push.onMensajeForeground = (m) {
      // Un pedido nuevo es urgente (timer de 30s): navega directo a la oferta en
      // vez de un SnackBar fácil de ignorar.
      if (m.tipo == 'PEDIDO_NUEVO' && m.pedidoId != null) {
        abrir(m);
        return;
      }
      final ctx = _router.routerDelegate.navigatorKey.currentContext;
      if (ctx == null) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(m.titulo ?? m.cuerpo ?? 'Tienes una actualización'),
          action: (m.pedidoId != null || m.tipo == 'BLOQUEO_DEUDA')
              ? SnackBarAction(label: 'Ver', onPressed: () => abrir(m))
              : null,
        ),
      );
    };
    await push.inicializar();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthRepository>.value(
      value: _auth,
      child: MaterialApp.router(
        title: 'motoYa Conductor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
        locale: const Locale('es', 'CO'),
        supportedLocales: const [Locale('es', 'CO'), Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}

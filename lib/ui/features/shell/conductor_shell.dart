import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../di/locator.dart';
import '../../core/tab_activa.dart';
import '../../core/widgets/barra_navegacion.dart';

/// Contenedor con barra inferior del conductor: Inicio · Billetera · Historial · Perfil.
class ConductorShell extends StatelessWidget {
  const ConductorShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _ir(int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
    // Avisa al tab que vuelve a ser visible para que refresque sus cifras.
    locator<TabActiva>().cambiar(index);
  }

  @override
  Widget build(BuildContext context) {
    final conductor = locator<ConductorRepository>();
    return Scaffold(
      body: shell,
      // El punto de aviso de Billetera se enciende con el bloqueo por deuda, y
      // por eso la barra escucha al repositorio. Es el único aviso que merece
      // un punto en esta app: mientras está encendido el conductor **no recibe
      // pedidos**, así que enterarse tarde le cuesta la mañana, y hasta ahora
      // solo se veía entrando a la Billetera — que es justo donde no entra
      // quien cree que hoy no hay trabajo.
      bottomNavigationBar: ListenableBuilder(
        listenable: conductor,
        builder: (context, _) => BarraNavegacion(
          indice: shell.currentIndex,
          onSeleccion: _ir,
          destinos: [
            const DestinoNav(
              icono: Icons.home_outlined,
              iconoActivo: Icons.home_rounded,
              etiqueta: 'Inicio',
            ),
            DestinoNav(
              icono: Icons.account_balance_wallet_outlined,
              iconoActivo: Icons.account_balance_wallet_rounded,
              etiqueta: 'Billetera',
              aviso: conductor.bloqueadoPorDeuda
                  ? 'Bloqueado por deuda: ponte al día para recibir pedidos'
                  : null,
            ),
            const DestinoNav(
              icono: Icons.receipt_long_outlined,
              iconoActivo: Icons.receipt_long_rounded,
              etiqueta: 'Historial',
            ),
            const DestinoNav(
              icono: Icons.person_outline_rounded,
              iconoActivo: Icons.person_rounded,
              etiqueta: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

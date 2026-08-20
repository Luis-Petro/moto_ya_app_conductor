import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'config/env.dart';
import 'data/services/banner_image_store.dart';
import 'data/services/map_tile_cache.dart';
import 'di/locator.dart';
import 'ui/core/theme/app_colors.dart';
import 'ui/core/theme/app_spacing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO');

  // En release, el `ErrorWidget` por defecto de Flutter pinta un rectángulo gris
  // **sin texto**: una excepción durante el build se ve exactamente igual que una
  // pantalla vacía o que un esqueleto de carga apagado. Eso convierte cualquier
  // fallo en un reporte de "se queda en blanco" que no se puede diagnosticar.
  ErrorWidget.builder = _avisoDeFallo;

  // Caché en disco de los tiles del mapa (bajo demanda). El conductor tiene el
  // mapa abierto todo el domicilio y recorre el mismo municipio a diario: sin
  // caché vuelve a descargar los mismos tiles con sus datos cada viaje.
  await MapTileCache.init();

  // Misma idea con las imágenes de los banners: se bajan una vez y se sirven de
  // disco durante 30 días. El conductor abre el Inicio decenas de veces al día.
  await BannerImageStore.init();

  // Firebase es opcional: solo se inicializa si está habilitado y configurado.
  if (Env.fcmEnabled) {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      /* sin google-services.json: la app sigue sin push */
    }
  }

  configurarDependencias();
  runApp(const ZumbeoConductorApp());
}

/// Reemplazo del `ErrorWidget` por defecto: dice que algo falló y ofrece salida.
///
/// No toca `FlutterError.onError`, así que el stack completo sigue saliendo por
/// consola y por el log del dispositivo igual que antes.
Widget _avisoDeFallo(FlutterErrorDetails detalles) =>
    _PantallaDeFallo(detalles: detalles);

class _PantallaDeFallo extends StatelessWidget {
  const _PantallaDeFallo({required this.detalles});

  final FlutterErrorDetails detalles;

  @override
  Widget build(BuildContext context) {
    // Un `ErrorWidget` puede sustituir a cualquier widget del árbol, incluso por
    // encima del `MaterialApp`: no se puede dar por hecho que haya Directionality,
    // tema ni Navigator. De ahí los widgets básicos y el `maybeOf`.
    final navegador = Navigator.maybeOf(context);
    final puedeVolver = navegador?.canPop() ?? false;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: AppColors.background,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                  size: 40,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Algo falló en esta pantalla',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  puedeVolver
                      ? 'Puedes volver e intentarlo otra vez.'
                      : 'Cierra la app y vuelve a abrirla.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 13.5,
                  ),
                ),
                // El mensaje técnico solo en debug: en release al conductor no le
                // sirve de nada y en cambio parece que la app se rompió más.
                if (kDebugMode) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    detalles.exception.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (puedeVolver) ...[
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: navegador!.pop,
                    child: const Text(
                      'Volver',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

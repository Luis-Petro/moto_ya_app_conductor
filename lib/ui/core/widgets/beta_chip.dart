import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Marca de "beta" de la app.
///
/// La plataforma está en pruebas con usuarios reales: decirlo cambia lo que la
/// gente espera cuando algo falla, y decirlo en la pantalla es más honesto que
/// esperar que lo deduzcan del número de versión.
class BetaChip extends StatelessWidget {
  const BetaChip({super.key, this.compacto = true});

  /// Compacto = solo "BETA" (para encabezados). Si no, "Versión en pruebas".
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Text(
        compacto ? 'BETA' : 'Versión en pruebas',
        // `primaryInk`, no `primary`: es texto naranja sobre una superficie
        // clara, el caso que no pasa AA (ver contraste_test.dart).
        style: AppText.label.copyWith(color: AppColors.primaryInk),
      ),
    );
  }
}

/// Marca de **entorno de pruebas**: esta app no habla con el backend real.
///
/// Es un dato distinto del de [BetaChip] y por eso es otro chip. "BETA" dice
/// que el producto está en pruebas con usuarios reales; esto dice que los datos
/// que se ven aquí no existen — los pedidos, la deuda y la plata son de
/// mentira. Confundirlos es pedirle a un conductor que reclame por una comisión
/// que nunca se cobró.
///
/// Color de aviso y no el naranja de marca: al lado del chip BETA tienen que
/// distinguirse de un vistazo, y `warningInk` sobre `warningSurface` es el par
/// que ya pasa contraste en el resto de la app.
///
/// Quien decide si se pinta es quien lo usa, mirando `Env.esProduccion`: este
/// widget solo sabe dibujarse.
class EntornoChip extends StatelessWidget {
  const EntornoChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.warning),
      ),
      child: Text(
        'PRUEBAS',
        style: AppText.label.copyWith(color: AppColors.warningInk),
      ),
    );
  }
}

/// Pie con la versión instalada y el aviso de beta.
///
/// Va en el perfil: es donde alguien mira cuando quiere reportar un problema, y
/// sin el número de versión un reporte no se puede reproducir.
class PieVersion extends StatefulWidget {
  const PieVersion({super.key});

  @override
  State<PieVersion> createState() => _PieVersionState();
}

class _PieVersionState extends State<PieVersion> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          const BetaChip(compacto: false),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _version == null ? 'Zumbeo' : 'Zumbeo ${_version!}',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

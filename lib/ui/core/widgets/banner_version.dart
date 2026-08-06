import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/services/app_version_service.dart';
import '../../../di/locator.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Aviso de versión nueva disponible. Siempre **descartable**: no hay
/// actualización forzada, así que nunca bloquea el uso de la app. Si la consulta
/// falla o la versión instalada está al día, no se pinta nada.
class BannerVersion extends StatefulWidget {
  const BannerVersion({super.key});

  @override
  State<BannerVersion> createState() => _BannerVersionState();
}

class _BannerVersionState extends State<BannerVersion> {
  VersionVigente? _nueva;
  bool _descartado = false;

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  Future<void> _consultar() async {
    final nueva = await locator<AppVersionService>().nuevaVersionDisponible();
    if (mounted) setState(() => _nueva = nueva);
  }

  Future<void> _descargar(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final nueva = _nueva;
    if (nueva == null || _descartado) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.system_update_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Versión ${nueva.version} disponible',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                if ((nueva.notas ?? '').trim().isNotEmpty)
                  Text(nueva.notas!.trim(),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkMuted)),
                if ((nueva.archivoUrl ?? '').isNotEmpty)
                  TextButton(
                    onPressed: () => _descargar(nueva.archivoUrl!),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Descargar ahora'),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Descartar',
            onPressed: () => setState(() => _descartado = true),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/services/app_version_service.dart';
import '../../../di/locator.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A dónde manda el botón del banner, con qué texto y con qué icono.
class DestinoActualizacion {
  const DestinoActualizacion({
    required this.url,
    required this.etiqueta,
    required this.icono,
  });

  final String url;
  final String etiqueta;
  final IconData icono;
}

/// Elige la tienda a la que manda el botón, según la plataforma.
///
/// Solo tiendas: **nunca** un APK. Por un lado, una app descargada de Google Play
/// no puede actualizarse por otra vía que Play (es política de la tienda, y el
/// APK del panel es solo para pruebas internas). Por otro, un `.apk` no se
/// instala en un iPhone.
///
/// Devuelve `null` cuando esa plataforma todavía no tiene enlace: el aviso se
/// pinta igual —hay versión nueva— pero sin botón, que es más honesto que un
/// botón que no lleva a ninguna parte.
DestinoActualizacion? destinoActualizacion({
  required TargetPlatform plataforma,
  String? playStoreUrl,
  String? appStoreUrl,
}) {
  final esIOS = plataforma == TargetPlatform.iOS;
  final url = (esIOS ? appStoreUrl : playStoreUrl)?.trim();
  if (url == null || url.isEmpty) {
    return null;
  }
  return DestinoActualizacion(
    url: url,
    etiqueta: esIOS ? 'Actualizar en el App Store' : 'Actualizar en Google Play',
    icono: esIOS ? Icons.apple : Icons.shop,
  );
}

/// Aviso de versión nueva disponible. Siempre **descartable**: no hay
/// actualización forzada, así que nunca bloquea el uso de la app. Si la consulta
/// falla o la versión instalada está al día, no se pinta nada.
///
/// Compara la versión instalada con la que el admin declaró como publicada en la
/// tienda (los APK de prueba del panel no cuentan, ver `AppVersionService`), y el
/// botón lleva a la tienda de la plataforma. Lo que se muestra son las novedades
/// que escribió el admin para los usuarios — nunca datos internos del build.
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

  Future<void> _abrir(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final nueva = _nueva;
    if (nueva == null || _descartado) return const SizedBox.shrink();
    final destino = destinoActualizacion(
      plataforma: defaultTargetPlatform,
      playStoreUrl: nueva.playStoreUrl,
      appStoreUrl: nueva.appStoreUrl,
    );
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
                if (destino != null)
                  TextButton.icon(
                    onPressed: () => _abrir(destino.url),
                    icon: Icon(destino.icono, size: 18),
                    label: Text(destino.etiqueta),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
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

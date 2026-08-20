import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/services/app_version_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'mascota_animada.dart';

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

/// Aviso de versión nueva disponible, como **tarjeta del carrusel de avisos**
/// (`CarruselBanners`), siempre la primera.
///
/// Va delante de cualquier banner publicado desde el panel porque es información
/// funcional de la propia app: que quede detrás de una promoción es exactamente
/// el orden equivocado.
///
/// Siempre **descartable**, y su descarte dura solo la sesión: una versión
/// desactualizada no deja de estarlo porque el usuario cerrara el aviso una vez.
/// El descarte persistente es de los banners del panel, que sí son campañas.
class TarjetaVersion extends StatelessWidget {
  const TarjetaVersion({
    super.key,
    required this.nueva,
    required this.onDescartar,
  });

  final VersionVigente nueva;
  final VoidCallback onDescartar;

  Future<void> _abrir(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final destino = destinoActualizacion(
      plataforma: defaultTargetPlatform,
      playStoreUrl: nueva.playStoreUrl,
      appStoreUrl: nueva.appStoreUrl,
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.primary),
      ),
      // El carrusel da una altura fija a todas las tarjetas (la del ratio de las
      // imágenes). En una pantalla muy estrecha el texto de esta podría no
      // caber, y un desbordamiento se vería como las franjas amarillas de Flutter
      // encima del Inicio: escalar es feo una vez, desbordar es feo siempre.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // La mascota con el teléfono en la mano, en vez del icono de sistema.
            // El banner no es un momento de espera, así que va quieta: aquí la
            // mascota es identidad de marca, no acompañamiento.
            const MascotaAnimada(pose: PoseMascota.actualizar, alto: 48),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Versión ${nueva.version} disponible',
                    style:
                        AppText.subtitle.copyWith(fontWeight: AppText.fuerte)),
                if ((nueva.notas ?? '').trim().isNotEmpty)
                  Text(nueva.notas!.trim(), style: AppText.caption),
                if (destino != null)
                  TextButton.icon(
                    onPressed: () => _abrir(destino.url),
                    icon: Icon(destino.icono, size: 18),
                    label: Text(destino.etiqueta),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      // 44 y no 32: el aviso se descarta con un toque al lado y
                      // el botón que lleva a la tienda era el más pequeño de la
                      // pantalla.
                      minimumSize: const Size(0, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            IconButton(
              tooltip: 'Descartar',
              onPressed: onDescartar,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

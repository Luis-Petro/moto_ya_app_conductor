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
    final notas = (nueva.notas ?? '').trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: LayoutBuilder(
        builder: (context, caja) => ColoredBox(
          color: AppColors.primarySurface,
          child: Stack(
            children: [
              // Lo único decorativo: el disco suave del fondo. Se dimensiona con
              // la caja porque el carrusel deriva la altura del ancho de la
              // pantalla, así que un tamaño fijo se vería enorme en una tablet.
              // El color sale del token de marca y no de un literal: si la
              // paleta cambia, esto cambia con ella.
              Positioned(
                right: -caja.maxHeight * 0.45,
                top: -caja.maxHeight * 0.35,
                child: Container(
                  width: caja.maxHeight * 1.6,
                  height: caja.maxHeight * 1.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight.withValues(alpha: 0.22),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, 0, AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // El texto va dentro de un `FittedBox` y el botón
                          // fuera, a propósito: el carrusel da una altura fija
                          // (la del ratio de las imágenes) y en una pantalla
                          // estrecha el texto podría no caber. Escalar el texto
                          // es feo una vez y desbordar es feo siempre —serían
                          // las franjas amarillas de Flutter encima del Inicio—,
                          // pero escalar el botón encogería su área táctil, y
                          // esa no se negocia.
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, texto) => FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: texto.maxWidth,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'NUEVA VERSIÓN',
                                        style: AppText.label.copyWith(
                                            color: AppColors.primaryInk),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Ya está lista la versión ${nueva.version}',
                                        style: AppText.subtitle.copyWith(
                                            fontWeight: AppText.fuerte),
                                      ),
                                      // `inkMuted` sobre `primarySurface` da
                                      // 4,35:1 y no llega a AA —el test de
                                      // contraste cubre ese gris sobre las
                                      // superficies blancas, no sobre esta—, así
                                      // que aquí el apoyo va en tinta.
                                      Text(
                                        notas.isEmpty
                                            ? 'Actualiza desde tu tienda de apps.'
                                            : notas,
                                        style: AppText.caption
                                            .copyWith(color: AppColors.ink),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (destino != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            _BotonTienda(
                                destino: destino,
                                onPulsar: () => _abrir(destino.url)),
                          ],
                        ],
                      ),
                    ),
                    // La mascota con el teléfono en la mano, en vez del icono de
                    // sistema. El aviso no es un momento de espera, así que va
                    // quieta: aquí la mascota es identidad de marca, no
                    // acompañamiento.
                    MascotaAnimada(
                      pose: PoseMascota.actualizar,
                      alto: caja.maxHeight * 0.86,
                    ),
                  ],
                ),
              ),
              // El velo oscuro que llevan los banners de imagen se vería como una
              // mancha sobre un fondo claro; un disco blanco translúcido logra lo
              // mismo —que la equis se lea también encima de la mascota— sin
              // ensuciar la tarjeta.
              Positioned(
                top: 0,
                right: 0,
                child: Material(
                  color: AppColors.surface.withValues(alpha: 0.72),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Descartar',
                    onPressed: onDescartar,
                    iconSize: 18,
                    color: AppColors.ink,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El botón que lleva a la tienda, como píldora de marca.
///
/// Va en azul marino y no en naranja: el naranja es el CTA del resto de la app y
/// este aviso no compite con lo que el conductor vino a hacer. Sobre el marino, el
/// blanco tiene contraste de sobra a cualquier tamaño, así que no le aplica la
/// regla de los 19 dp que sí rige para el blanco sobre naranja.
class _BotonTienda extends StatelessWidget {
  const _BotonTienda({required this.destino, required this.onPulsar});

  final DestinoActualizacion destino;
  final VoidCallback onPulsar;

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(AppSpacing.radiusLg);
    return Material(
      color: AppColors.accent,
      borderRadius: radio,
      child: InkWell(
        onTap: onPulsar,
        borderRadius: radio,
        child: ConstrainedBox(
          // 44 y no 32: el aviso se descarta con un toque al lado, y el botón que
          // lleva a la tienda era el más pequeño de la pantalla.
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(destino.icono, size: 16, color: AppColors.surface),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    destino.etiqueta,
                    style: AppText.caption.copyWith(
                        color: AppColors.surface, fontWeight: AppText.fuerte),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Foto a pantalla completa, con zoom y arrastre.
///
/// Las fotos del pedido y de la entrega se pintaban en recuadros de 150 px
/// recortados con `BoxFit.cover`: una fachada, un recibo o la placa de una casa
/// no se leen así, y son justo lo que hay que mirar cuando algo se discute.
///
/// Usa `InteractiveViewer`, que viene con Flutter: un paquete de terceros para
/// esto sería una dependencia más en dos apps que ya se publican en tiendas.
class VisorFoto extends StatelessWidget {
  const VisorFoto({super.key, required this.url, this.titulo});

  final String url;
  final String? titulo;

  /// Abre el visor sobre la pantalla actual.
  ///
  /// `useRootNavigator: true` a propósito: la foto debe tapar también la barra
  /// de pestañas, y aquí no aplica el problema del velo negro de los diálogos
  /// dentro del shell porque esto es una ruta completa, no un `showDialog`.
  static Future<void> abrir(BuildContext context, String url, {String? titulo}) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => VisorFoto(url: url, titulo: titulo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: titulo == null
            ? null
            : Text(titulo!, style: const TextStyle(fontSize: 16)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (_, __, ___) => const _NoCargo(),
          ),
        ),
      ),
    );
  }
}

class _NoCargo extends StatelessWidget {
  const _NoCargo();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.white70, size: 32),
          SizedBox(height: AppSpacing.sm),
          Text(
            'No pudimos cargar la foto',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// Miniatura que anuncia que se puede ampliar.
///
/// Sin el icono, una foto tocable no se toca: nada en pantalla dice que lo sea.
class FotoAmpliable extends StatelessWidget {
  const FotoAmpliable({
    super.key,
    required this.url,
    this.titulo,
    this.alto = 150,
    this.child,
  });

  final String url;
  final String? titulo;
  final double alto;

  /// Contenido de la miniatura; por defecto, la propia foto recortada.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => VisorFoto.abrir(context, url, titulo: titulo),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: child ??
                Image.network(
                  url,
                  height: alto,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: alto,
                    color: AppColors.mapPlaceholder,
                    alignment: Alignment.center,
                    child: const Text(
                      'No pudimos cargar la foto',
                      style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
                    ),
                  ),
                ),
          ),
          Positioned(
            right: AppSpacing.xs,
            bottom: AppSpacing.xs,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(Icons.zoom_out_map, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

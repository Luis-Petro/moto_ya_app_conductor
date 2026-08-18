import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Pregunta de dónde sale la foto: cámara o galería.
///
/// **Estaba escrita tres veces** —foto de perfil en el Inicio, comprobante en la
/// billetera y documentos— y en las tres era lo mismo: dos `ListTile` sueltos
/// sobre el gris de Material, sin decir de qué eran, y con tocar fuera como
/// única salida visible.
///
/// Lo que cambia aquí, por orden de importancia:
///
/// - **Asa y título.** Una hoja que aparece sin encabezado no dice de qué foto
///   está hablando, y en la pantalla de documentos hay cuatro.
/// - **"Ahora no" explícito.** Salir tocando el velo es evidente para quien vive
///   en el teléfono; para el resto, la hoja no tiene salida. Un botón de
///   descarte con su propia área táctil no le quita nada a nadie.
/// - **Opciones como tarjeta con el icono en disco**, no como fila de lista: son
///   dos acciones, no dos ajustes.
///
/// Devuelve `null` si se descarta, que es lo que ya esperaban los tres sitios.
Future<ImageSource?> elegirFotoSheet(
  BuildContext context, {
  required String titulo,

  /// Una línea de contexto: qué tiene que salir en la foto. Es lo que evita el
  /// viaje de vuelta con la foto equivocada.
  String? contexto,
}) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    // Sin esto, dentro de un tab del StatefulShellRoute el velo se pinta sobre
    // el shell. El default de `showModalBottomSheet` ya es false; se deja
    // escrito porque es el fallo que deja la pantalla en negro.
    useRootNavigator: false,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asa: dice que la hoja se arrastra, antes de que haga falta.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              titulo,
              style: AppText.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (contexto != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                contexto,
                style: AppText.body.copyWith(color: AppColors.inkMuted),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            // La cámara va primero: nueve de cada diez fotos de esta app se
            // toman en el momento (el documento en la mano, el comprobante en
            // la pantalla del banco), no se buscan en el carrete.
            _OpcionFoto(
              icono: Icons.photo_camera_rounded,
              titulo: 'Tomar foto',
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
            _OpcionFoto(
              icono: Icons.photo_library_rounded,
              titulo: 'Elegir de la galería',
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.inkMuted,
                  minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
                ),
                child: const Text('Ahora no'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Una de las dos procedencias, como acción y no como fila de ajustes.
class _OpcionFoto extends StatelessWidget {
  const _OpcionFoto({
    required this.icono,
    required this.titulo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          // El alto sale del relleno vertical, no de una altura fija: con la
          // escala de texto del sistema al 130 % una altura fija recorta el
          // texto, y con `constraints` + `alignment` la fila se estira.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  titulo,
                  style: AppText.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

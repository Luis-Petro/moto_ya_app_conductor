import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Fila de una credencial (correo o celular): muestra la actual, si está
/// verificada, y ofrece cambiarla por su flujo de dos pasos.
///
/// Ninguna de las dos se edita en línea: ambas son credenciales de acceso y
/// aplicar un valor sin comprobar que es tuyo abre la puerta a perder la cuenta.
///
/// Vive en `core/widgets` y no dentro del perfil porque la disposición es lo
/// que se rompió y hay que poder probarla: `test/ui/credencial_tile_test.dart`
/// la monta a 320 dp y comprueba que el valor no se parte.
class CredencialTile extends StatelessWidget {
  const CredencialTile({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.vacio,
    required this.onCambiar,
    this.valor,
    this.verificado,
    this.onVerificar,
  });

  final String etiqueta;
  final IconData icono;
  final String vacio;
  final String? valor;
  final bool? verificado;
  final VoidCallback onCambiar;

  /// Verificar el dato **actual** (sin cambiarlo). Nulo = no aplica.
  final VoidCallback? onVerificar;

  @override
  Widget build(BuildContext context) {
    final tiene = (valor ?? '').isNotEmpty;
    final sinVerificar = tiene && verificado == false;
    // Vertical, no horizontal. Antes el icono, la etiqueta, el valor, el
    // distintivo y **dos botones** compartían un solo `Row`: en un teléfono
    // estrecho no cabían, y lo que cedía era el valor, que se partía carácter a
    // carácter ("300 / 1234 / 567"). Un correo o un celular en tres renglones
    // no se puede ni leer ni dictar por teléfono.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, color: AppColors.inkMuted, size: 18),
            const SizedBox(width: AppSpacing.sm),
            // `Expanded` con recorte, no `Spacer`: con la escala de texto al
            // 130 % la etiqueta y el sello juntos pasan de los 288 dp útiles de
            // un teléfono de 320, y con `Spacer` la fila desbordaba. Aquí cede
            // la etiqueta, que es la parte que ya se adivina por el icono.
            Expanded(
              child: Text(
                etiqueta.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label,
              ),
            ),
            if (tiene && verificado != null) ...[
              const SizedBox(width: AppSpacing.sm),
              _SelloVerificacion(ok: verificado!),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // El valor manda en su propio renglón, entero y sin competencia. Si no
        // cabe, se recorta con puntos suspensivos: mejor un correo largo
        // truncado que uno completo ilegible.
        Text(
          tiene ? valor! : vacio,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.subtitle.copyWith(
            color: tiene ? AppColors.ink : AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // `Wrap` y no `Row`: con la escala de texto del sistema al 130 % los
        // dos botones suman más que el ancho de un teléfono de 320 dp y un
        // `Row` desborda. Así el segundo baja de renglón, que es feo pero
        // legible — y es lo que hace la diferencia para quien necesita el
        // texto grande.
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            // "Verificar" solo aparece cuando el dato existe y está sin
            // verificar. Antes no había forma de confirmarlo: la única opción
            // era "cambiarlo" por el mismo valor, que el backend rechaza por
            // unicidad.
            //
            // Va primero y con el color de marca porque es lo que hay que
            // hacer; "Cambiar" es mantenimiento y va apagada. Dos botones
            // naranjas uno al lado del otro no decían cuál era cuál.
            if (sinVerificar && onVerificar != null)
              TextButton(
                onPressed: onVerificar,
                child: const Text('Verificar'),
              ),
            TextButton(
              onPressed: onCambiar,
              style: TextButton.styleFrom(
                foregroundColor:
                    sinVerificar ? AppColors.inkMuted : AppColors.primaryInk,
              ),
              child: Text(tiene ? 'Cambiar' : 'Agregar'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Estado de verificación de una credencial, como sello compacto.
///
/// Va arriba a la derecha, en la línea de la etiqueta, y no pegado al valor:
/// ahí era lo que empujaba al correo a partirse en varios renglones.
class _SelloVerificacion extends StatelessWidget {
  const _SelloVerificacion({required this.ok});

  final bool ok;

  @override
  Widget build(BuildContext context) {
    // Tintas, no rellenos: es texto sobre una superficie clara, y el verde y
    // el ámbar de relleno ahí no pasan AA.
    final tinta = ok ? AppColors.successInk : AppColors.warningInk;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: ok ? AppColors.successSurface : AppColors.warningSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.verified_rounded : Icons.error_outline_rounded,
            size: 13,
            color: tinta,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(ok ? 'Verificado' : 'Sin verificar',
              style: AppText.caption.copyWith(color: tinta)),
        ],
      ),
    );
  }
}

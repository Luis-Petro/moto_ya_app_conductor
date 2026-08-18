import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'mascota_animada.dart';
import 'primary_button.dart';

/// Estado de vista genérico para manejar carga/error/vacío de forma uniforme,
/// evitando que cada pantalla reinvente estos estados (anti-patrón mobile:
/// "no loading / no error state").
enum ViewStatus { idle, loading, error, ready }

/// Espera con el motivo escrito.
///
/// Un aro girando y nada más no distingue "estoy buscando tu pedido" de "me
/// quedé colgada", y esa duda dura justo lo que dura la espera. Cuesta una
/// línea decirlo.
///
/// Vive aquí y no en cada pantalla porque ya iban cuatro copias de lo mismo
/// —seguimiento, cierre, detalle y perfil—, que es exactamente lo que este
/// cambio corrige.
class CargandoConMensaje extends StatelessWidget {
  const CargandoConMensaje(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(mensaje, textAlign: TextAlign.center, style: AppText.caption),
        ],
      ),
    );
  }
}

/// Composición común de todos los estados de cierre y de vacío.
///
/// Existe porque el vacío era el sitio donde la app parecía a medio hacer:
/// "Pedido cancelado" eran dos líneas en mitad de una pantalla en blanco. Un
/// vacío sin trabajar se lee como un error del sistema justo en el momento en
/// que el cliente está esperando algo.
///
/// La estructura no es negociable —ilustración, título, explicación, acción—
/// porque es lo que distingue un estado de una pantalla rota: la ilustración
/// dice que estaba previsto, el título dice qué pasó y la acción dice cómo
/// sigue esto. Un vacío sin salida es un callejón.
class _BloqueEstado extends StatelessWidget {
  const _BloqueEstado({
    required this.figura,
    required this.titulo,
    this.explicacion,
    this.accion,
    this.accionSecundaria,
  });

  final Widget figura;
  final String titulo;
  final String? explicacion;
  final Widget? accion;
  final Widget? accionSecundaria;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        // Con la escala de texto del sistema al 130 % y la mascota encima, el
        // bloque no cabe en una pantalla corta. Antes desbordaba; ahora rueda.
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            figura,
            const SizedBox(height: AppSpacing.lg),
            Text(titulo, textAlign: TextAlign.center, style: AppText.title),
            if (explicacion != null) ...[
              const SizedBox(height: AppSpacing.sm),
              // Ancho acotado: una explicación a todo lo ancho del teléfono se
              // lee peor que la misma en tres renglones cortos.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  explicacion!,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.inkMuted),
                ),
              ),
            ],
            if (accion != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(width: double.infinity, child: accion),
            ],
            if (accionSecundaria != null) ...[
              const SizedBox(height: AppSpacing.sm),
              // Menos peso que la principal a propósito: cuando las dos salidas
              // pesan igual, la pantalla no recomienda ninguna.
              SizedBox(width: double.infinity, child: accionSecundaria),
            ],
          ],
        ),
      ),
    );
  }
}

/// Vista de error reutilizable con acción de reintento.
///
/// **Un fallo de red no se ve como los demás.** Con `esRed`, en lugar del icono
/// gris aparece la mascota sin conexión y un texto que nombra la causa. La
/// distinción no es decorativa: "revisa tu conexión" delante de un 409 manda a
/// alguien a reiniciar el router durante media hora por un permiso denegado.
/// Por eso el valor por defecto es `false` — quien no lo declare conserva el
/// mensaje que devolvió el backend, que es lo correcto para todo lo que no sea
/// falta de internet.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
    this.esRed = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  /// Si el fallo fue de conectividad. Se pasa desde `Failure.isNetwork`.
  final bool esRed;

  @override
  Widget build(BuildContext context) {
    return _BloqueEstado(
      figura: esRed
          ? const MascotaAnimada(pose: PoseMascota.sinConexion)
          : _IconoEnCirculo(icon: icon, color: AppColors.danger),
      titulo: esRed ? 'Sin conexión' : 'No se pudo cargar',
      explicacion: esRed
          ? 'No pudimos conectarnos. Revisa tu internet e inténtalo de nuevo.'
          : message,
      accion: onRetry == null
          ? null
          : PrimaryButton(
              label: 'Reintentar',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
    );
  }
}

/// Estado vacío reutilizable.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.accionSecundaria,
    this.ilustracion,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  /// Segunda salida, cuando el estado tiene dos (reintentar la búsqueda o
  /// cancelar el pedido). Se pinta con menos peso que [action].
  final Widget? accionSecundaria;

  /// Dibujo en lugar del icono, para los vacíos que merecen una cara.
  ///
  /// No todos: un historial sin pedidos no necesita a nadie consolándote. Se usa
  /// donde el vacío es un desenlace —nadie tomó tu pedido— y no un estado
  /// neutro.
  final Widget? ilustracion;

  @override
  Widget build(BuildContext context) {
    return _BloqueEstado(
      figura: ilustracion ?? _IconoEnCirculo(icon: icon),
      titulo: title,
      explicacion: subtitle,
      accion: action,
      accionSecundaria: accionSecundaria,
    );
  }
}

/// El icono de un estado, sobre un disco de su color.
///
/// Un icono suelto de 56 px en gris claro sobre fondo casi blanco es lo que
/// hacía que estas pantallas parecieran sin terminar: no tenía peso suficiente
/// para ser el ancla visual del bloque, ni contraste para leerse al sol.
class _IconoEnCirculo extends StatelessWidget {
  const _IconoEnCirculo({required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tinte = color ?? AppColors.primary;
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: tinte.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 40, color: tinte),
    );
  }
}

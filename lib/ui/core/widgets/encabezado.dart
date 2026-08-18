import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// El encabezado de la app.
///
/// **Existe por un fallo concreto de navegación.** `AppBar()` solo pinta la
/// flecha de retroceso si hay algo que desapilar. Varias pantallas de acceso se
/// alcanzan con `context.go`, que *reemplaza* la pila: la flecha desaparece y
/// quien entró por error queda atrapado, con el botón del sistema como única
/// salida. Le pasaba a la selección de perfil ("¿Cómo quieres usar Zumbeo?") y
/// `RegistroScreen` ya lo había resuelto a mano con un `leading` propio.
///
/// Aquí eso deja de ser algo que cada pantalla tiene que recordar: si se pasa
/// [onAtras], **la flecha se pinta siempre**, haya pila o no.
///
/// ```dart
/// appBar: encabezado('¿Cómo quieres usar Zumbeo?',
///     onAtras: () => context.go(Rutas.onboarding)),
/// ```
PreferredSizeWidget encabezado(
  String? titulo, {
  VoidCallback? onAtras,

  /// Qué hace la flecha cuando no se declara [onAtras]: desapilar. Es el
  /// comportamiento normal y sirve para todo lo que se abre con `push`.
  bool conRetroceso = true,
  List<Widget>? acciones,
  Color fondo = AppColors.surface,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    backgroundColor: fondo,
    surfaceTintColor: Colors.transparent,
    // Recortado y en una línea. Un `AppBar` no recorta por su cuenta: un título
    // largo con la escala de texto del sistema al 130 % desborda con la franja
    // amarilla y negra encima del encabezado. Recortar es feo; desbordar es un
    // fallo a la vista de todo el mundo.
    title: titulo == null
        ? null
        : Text(titulo,
            style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    // `automaticallyImplyLeading` es justo lo que falla cuando no hay pila:
    // devuelve null y el título se pega al borde. Con `onAtras` el botón lo
    // pone esta función, así que no se delega en Flutter la decisión.
    automaticallyImplyLeading: onAtras == null && conRetroceso,
    leading: onAtras == null ? null : _BotonAtras(onAtras: onAtras),
    actions: acciones,
    bottom: bottom,
  );
}

class _BotonAtras extends StatelessWidget {
  const _BotonAtras({required this.onAtras});

  final VoidCallback onAtras;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      color: AppColors.ink,
      // Lo lee el lector de pantalla y lo muestra la pulsación larga. Sin él,
      // la flecha se anuncia como "botón" a secas.
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onAtras,
    );
  }
}

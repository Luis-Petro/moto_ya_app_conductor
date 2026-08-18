import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// Tema central de Zumbeo. Todas las pantallas leen colores y tipografía de
/// aquí; no se hardcodean valores de marca por pantalla.
class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      error: AppColors.danger,
      surface: AppColors.surface,
      brightness: Brightness.light,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      // Tipografía propia empaquetada (ver pubspec). Antes decía 'Roboto' sin
      // empaquetar nada, así que en Android resolvía a la fuente del
      // fabricante: la app se veía distinta en cada teléfono y ninguna de esas
      // versiones era la elegida.
      fontFamily: AppText.familia,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      // Los roles de `AppText` mapeados al TextTheme, para que los widgets que
      // no reciben estilo explícito (ListTile, SnackBar, AppBar, Dialog)
      // hereden la escala en vez de quedarse con la de Material.
      textTheme: base.textTheme.copyWith(
        displaySmall: AppText.display,
        headlineSmall: AppText.display,
        titleLarge: AppText.title,
        titleMedium: AppText.subtitle,
        titleSmall: AppText.subtitle,
        bodyLarge: AppText.body,
        bodyMedium: AppText.body,
        bodySmall: AppText.caption,
        labelLarge: AppText.subtitle,
        labelMedium: AppText.caption,
        labelSmall: AppText.label,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: AppText.title,
        iconTheme: IconThemeData(color: AppColors.ink, size: 24),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        // El texto de ejemplo (hint) debe leerse como ejemplo, no como dato ya
        // escrito: gris apagado y en cursiva. Sin esto se veía igual que el
        // contenido real y la gente creía que el campo ya estaba lleno.
        hintStyle: AppText.body.copyWith(
          color: AppColors.inkMuted.withValues(alpha: 0.65),
          fontStyle: FontStyle.italic,
        ),
        helperStyle: AppText.caption,
        errorStyle: AppText.caption.copyWith(color: AppColors.danger),
        labelStyle: AppText.body.copyWith(color: AppColors.inkMuted),
        floatingLabelStyle: AppText.caption.copyWith(color: AppColors.primaryInk),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.inkMuted,
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget + 8),
          elevation: 0,
          textStyle: AppText.cta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ).copyWith(
          // El velo gris que pone Material al pulsar sobre el naranja se ve
          // sucio; el pulsado tiene su propio tono de marca.
          overlayColor: WidgetStateProperty.resolveWith((estados) =>
              estados.contains(WidgetState.pressed)
                  ? AppColors.primaryPressed
                  : null),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          // Misma altura que el primario para que una barra con los dos no
          // quede escalonada. El texto sí es más discreto: es la acción
          // secundaria, y aquí es tinta sobre blanco, que ya pasa AA de sobra.
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget + 8),
          side: const BorderSide(color: AppColors.line),
          textStyle: AppText.subtitle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        // `primaryInk` y no `primary`: como texto, el naranja de marca sobre
        // blanco da 3,1:1 y no pasa AA.
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryInk,
          textStyle: AppText.subtitle,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.inkMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        // La sombra la pinta el shell con `AppElevation.anclada` (hacia
        // arriba); la de Material va hacia abajo y aquí no hay nada debajo.
        elevation: 0,
        selectedLabelStyle: AppText.caption.copyWith(color: AppColors.primary),
        unselectedLabelStyle: AppText.caption,
      ),
      // Los chips de Material (las sugerencias de descripción y los sitios del
      // municipio en el asistente). Iban cada uno con su tamaño y su color a
      // mano y no se parecían entre sí, aunque en la misma pantalla significan
      // lo mismo: "toca esto y te ahorras escribir".
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySurface,
        labelStyle: AppText.body.copyWith(fontWeight: AppText.medio),
        secondaryLabelStyle: AppText.body.copyWith(fontWeight: AppText.medio),
        checkmarkColor: AppColors.primaryInk,
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        // El borde también cambia al seleccionar, no solo el relleno: dos tonos
        // de naranja claro se distinguen mal de reojo y nada de eso llega a
        // quien no separa esos tonos.
        side: WidgetStateBorderSide.resolveWith((estados) =>
            estados.contains(WidgetState.selected)
                ? const BorderSide(color: AppColors.primary, width: 1.6)
                : const BorderSide(color: AppColors.line)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.body.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppText.title,
        contentTextStyle: AppText.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
    );
  }
}

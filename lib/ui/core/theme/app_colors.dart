import 'package:flutter/material.dart';

/// Paleta de marca Zumbeo, alineada al logo (naranja + azul marino).
class AppColors {
  const AppColors._();

  // Marca (naranja del logo)
  static const Color primary = Color(0xFFF2641E); // naranja Zumbeo (CTAs)
  static const Color primaryDark = Color(0xFFC94E12);
  static const Color primaryLight = Color(0xFFF59A5E);
  static const Color primarySurface = Color(
    0xFFFCEDE4,
  ); // fondos suaves naranja

  // Acento (azul marino del logo) — énfasis de precio / contraoferta
  static const Color accent = Color(0xFF17293D);
  static const Color accentSurface = Color(0xFFE9EEF3);

  // Estados
  static const Color success = Color(0xFF1FA971);
  static const Color successSurface = Color(0xFFEAF7F1);
  static const Color danger = Color(0xFFE5484D);
  static const Color dangerSurface = Color(0xFFFDEBEC);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFEF3E2);

  // Neutros (texto en azul marino del logo)
  static const Color ink = Color(0xFF17293D); // texto principal
  static const Color inkMuted = Color(0xFF64748B); // texto secundario
  static const Color line = Color(0xFFE3E8EE); // bordes/divisores
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7F8FA);
  static const Color mapPlaceholder = Color(0xFFDFE5EC);

  /// Relleno de los bloques de carga (`Skeleton`).
  ///
  /// Tiene que ser bastante más oscuro que `line` o `mapPlaceholder` porque el
  /// fondo ya es casi blanco y el bloque se pinta **con opacidad**: sobre
  /// `background` da 1,42:1 en el punto más apagado de la animación y 1,84:1 a
  /// opacidad plena. Con `line` (#E3E8EE) daba **1,06:1**, que es literalmente una
  /// pantalla vacía; con `mapPlaceholder` da 1,19:1 incluso sin animar. Hay un
  /// test que fija el suelo en 1,4:1 (`test/ui/skeleton_visible_test.dart`).
  static const Color skeleton = Color(0xFFB3BAC5);

  static const Color star = Color(0xFFF5A623);
}

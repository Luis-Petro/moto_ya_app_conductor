import 'package:flutter/material.dart';

/// Paleta de marca motoYa, alineada al logo (naranja + azul marino).
class AppColors {
  const AppColors._();

  // Marca (naranja del logo)
  static const Color primary = Color(0xFFF2641E); // naranja motoYa (CTAs)
  static const Color primaryDark = Color(0xFFC94E12);
  static const Color primaryLight = Color(0xFFF59A5E);
  static const Color primarySurface = Color(0xFFFCEDE4); // fondos suaves naranja

  // Acento (azul marino del logo) — énfasis de precio / contraoferta
  static const Color accent = Color(0xFF17293D);
  static const Color accentSurface = Color(0xFFE9EEF3);

  // Estados
  static const Color success = Color(0xFF1FA971);
  static const Color danger = Color(0xFFE5484D);
  static const Color dangerSurface = Color(0xFFFDEBEC);
  static const Color warning = Color(0xFFF59E0B);

  // Neutros (texto en azul marino del logo)
  static const Color ink = Color(0xFF17293D); // texto principal
  static const Color inkMuted = Color(0xFF64748B); // texto secundario
  static const Color line = Color(0xFFE3E8EE); // bordes/divisores
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7F8FA);
  static const Color mapPlaceholder = Color(0xFFDFE5EC);

  static const Color star = Color(0xFFF5A623);
}

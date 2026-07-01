/// Escala de espaciado y radios consistente para toda la app.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // Radios
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;

  /// Área táctil mínima recomendada (Android 48dp / iOS 44pt → 48 cubre ambos).
  static const double minTouchTarget = 48;
}

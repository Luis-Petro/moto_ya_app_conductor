import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Escala tipográfica de la app: seis roles con nombre y dos pesos.
///
/// Existe porque los tamaños se escribían a mano en cada pantalla —solo el
/// Inicio tenía ocho valores distintos (22, 17, 13, 12.5, 11.5…)— y sin una
/// escala declarada cada pantalla nueva inventaba la suya. Ningún archivo de
/// `ui/features/` debe declarar un `fontSize`: lo vigila
/// `test/ui/tokens_ui_test.dart`.
///
/// Los nombres son de uso, no de Material (`headlineSmall`, `bodyMedium` no
/// dicen nada sobre dónde va cada uno en esta app).
class AppText {
  const AppText._();

  /// Familia empaquetada (ver `pubspec.yaml` y `tools/subsetear-fuente.py`).
  static const String familia = 'PlusJakartaSans';

  // Los tres pesos que viajan en el paquete. Pedir uno intermedio obliga a
  // Flutter a sintetizarlo y el resultado se ve sucio en pantallas densas.
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medio = FontWeight.w600;
  static const FontWeight fuerte = FontWeight.w800;

  /// Título de pantalla de acceso ("¿Cómo quieres usar Zumbeo?").
  static const TextStyle display = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: fuerte,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );

  /// Título de encabezado y de sección ("Mis pedidos", "Buscando conductor…").
  static const TextStyle title = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: fuerte,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  /// Título de tarjeta y de fila de lista.
  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: medio,
    color: AppColors.ink,
  );

  /// Cuerpo, descripciones y texto de apoyo.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: regular,
    color: AppColors.ink,
  );

  /// Etiquetas, pies y metadatos. Peso 600 y no 400: a 12 px sobre gris el
  /// regular se disuelve y la etiqueta deja de leerse al sol.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: medio,
    color: AppColors.inkMuted,
  );

  /// Texto de la acción principal sobre el naranja de marca.
  ///
  /// 19 dp y peso 800 no es una preferencia estética: el blanco sobre
  /// `#F2641E` da 3,17:1 y no llega al 4,5:1 que WCAG pide para texto normal.
  /// A partir de 18,66 px en negrita el listón baja a 3:1 —lo que WCAG llama
  /// texto grande— y 3,17 sí lo pasa. Así el CTA es accesible **sin tocar el
  /// naranja de la marca**, que era la otra salida. Lo vigila
  /// `test/ui/contraste_test.dart`.
  ///
  /// Consecuencia: nada por debajo de este tamaño se escribe en blanco sobre
  /// el naranja. Si hace falta una segunda línea, va sobre otra superficie.
  static const TextStyle cta = TextStyle(
    fontSize: 19,
    height: 24 / 19,
    fontWeight: fuerte,
    letterSpacing: -0.1,
  );

  /// Cifra de dinero destacada. Lleva figuras tabulares: sin ellas, un valor
  /// que se actualiza en vivo (una contrapropuesta que entra) cambia de ancho
  /// y desplaza lo que tiene al lado.
  static const TextStyle money = TextStyle(
    fontSize: 26,
    height: 30 / 26,
    fontWeight: fuerte,
    letterSpacing: -0.4,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// La misma cifra dentro de una lista o una fila.
  static const TextStyle moneySm = TextStyle(
    fontSize: 18,
    height: 22 / 18,
    fontWeight: fuerte,
    letterSpacing: -0.2,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Etiqueta en versalitas de los formularios ("NOMBRE COMPLETO", "CORREO").
  /// El interletraje abierto es lo que hace legible un texto en mayúsculas.
  static const TextStyle label = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: fuerte,
    letterSpacing: 0.8,
    color: AppColors.inkMuted,
  );
}

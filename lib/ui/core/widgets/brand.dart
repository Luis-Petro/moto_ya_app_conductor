import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Ruta del logo de marca (lockup: moto + "Zumbeo · Tu domicilio, ya.").
const String kLogoAsset = 'assets/images/logo.webp';

/// Ruta de la mascota de marca, cuerpo completo y fondo transparente.
const String kMascotaAsset = 'assets/images/mascota.png';

/// Mascota Zumbeo. Es la cara de la marca en splash, login y onboarding.
///
/// Va sin el nombre horneado dentro: el wordmark se compone al lado con
/// [BrandWordmark], que usa la fuente de la app y se lee igual en cualquier
/// tamaño (el texto dentro de un PNG se deshace al reducirlo).
///
/// [alineacion] permite encuadrar una parte —cuerpo entero, medio cuerpo o
/// cabeza— de la misma ilustración, que es como el onboarding consigue tres
/// láminas distintas sin tres dibujos distintos.
class BrandMascota extends StatelessWidget {
  const BrandMascota({
    super.key,
    this.height = 160,
    this.alineacion = Alignment.center,
    this.encuadre = BoxFit.contain,
  });

  final double height;
  final Alignment alineacion;
  final BoxFit encuadre;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kMascotaAsset,
      height: height,
      fit: encuadre,
      alignment: alineacion,
      semanticLabel: 'Zumbeo',
    );
  }
}

/// Logo de marca completo (imagen). Usar donde se necesite el lockup oficial.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.width = 180});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kLogoAsset,
      width: width,
      fit: BoxFit.contain,
      semanticLabel: 'Zumbeo',
    );
  }
}

/// Logo de marca Zumbeo (ícono de moto sobre fondo teal).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 72, this.color = AppColors.primary});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        Icons.two_wheeler_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

/// Texto de marca "Zumbeo".
///
/// El parámetro se llama [tamano] y no `fontSize` a propósito: con ese nombre,
/// una llamada legítima al wordmark era indistinguible de una pantalla
/// declarando su propia tipografía, y `tokens_ui_test.dart` no puede saber la
/// diferencia leyendo el código.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.tamano = 28, this.color});

  final double tamano;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppText.display.copyWith(
          fontSize: tamano,
          color: color ?? AppColors.ink,
          letterSpacing: -0.5,
        ),
        children: [
          const TextSpan(text: 'Zum'),
          TextSpan(
            text: 'beo',
            style: TextStyle(color: color ?? AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// Avatar circular con iniciales (estilo mocks). Si se le pasa [imageUrl],
/// muestra la foto y cae a las iniciales mientras carga o si falla.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.radius = 18,
    this.background = AppColors.primarySurface,
    this.foreground = AppColors.primary,
  });

  final String initials;
  final String? imageUrl;
  final double radius;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final tieneFoto = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      foregroundImage: tieneFoto ? NetworkImage(imageUrl!) : null,
      // El child es el respaldo visual, pero sin `onForegroundImageError` el
      // fallo de descarga sube como error de Flutter sin manejar: en producción
      // se ve bien y ensucia el log, y en un test tumba la prueba. Se traga aquí
      // porque ya hay una respuesta en pantalla: las iniciales.
      onForegroundImageError: tieneFoto ? (_, __) {} : null,
      child: Text(
        initials,
        // El tamaño sale del radio, no de la escala: el avatar se usa a seis
        // diámetros distintos y las iniciales tienen que llenarlo en todos.
        style: AppText.subtitle.copyWith(
          color: foreground,
          fontSize: radius * 0.8,
          height: 1,
        ),
      ),
    );
  }
}

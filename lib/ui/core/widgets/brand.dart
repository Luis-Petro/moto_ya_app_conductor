import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ruta del logo de marca (lockup: moto + "Zumbeo · Tu domicilio, ya.").
const String kLogoAsset = 'assets/images/logo.png';

/// Ruta de la mascota de marca, cuerpo completo y fondo transparente.
const String kMascotaAsset = 'assets/images/mascota.png';

/// Mascota Zumbeo. Es la cara de la marca en splash, login y pantallas vacías.
///
/// Va sin el nombre horneado dentro: el wordmark se compone al lado con
/// [BrandWordmark], que usa la fuente de la app y se lee igual en cualquier
/// tamaño (el texto dentro de un PNG se deshace al reducirlo).
class BrandMascota extends StatelessWidget {
  const BrandMascota({super.key, this.height = 160});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kMascotaAsset,
      height: height,
      fit: BoxFit.contain,
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
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.fontSize = 28, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
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
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

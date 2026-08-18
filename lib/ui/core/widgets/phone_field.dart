import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Campo de celular con prefijo de país (+57 Colombia).
class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.controller, this.label = 'Celular'});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.label),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Container(
              constraints: const BoxConstraints(
                  minHeight: AppSpacing.minTouchTarget + 8),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Text('co +57', style: AppText.subtitle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(hintText: '300 123 4567'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Normaliza un celular colombiano a formato E.164 (+57XXXXXXXXXX).
String normalizarTelefonoCo(String entrada) {
  final digitos = entrada.replaceAll(RegExp(r'\D'), '');
  return '+57$digitos';
}

bool telefonoCoValido(String entrada) {
  final digitos = entrada.replaceAll(RegExp(r'\D'), '');
  return digitos.length == 10;
}

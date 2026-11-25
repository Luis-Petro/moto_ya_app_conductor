import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/env.dart';
import '../theme/app_spacing.dart';

/// El número de soporte como se le enseña a una persona: `+57 350 485 9462`.
String soporteLegible() {
  final n = Env.soporteWhatsapp;
  if (n.length == 12 && n.startsWith('57')) {
    return '+57 ${n.substring(2, 5)} ${n.substring(5, 8)} ${n.substring(8)}';
  }
  return '+$n';
}

/// Abre el chat de WhatsApp con soporte de Zumbeo.
///
/// Si el teléfono no puede abrirlo (no hay WhatsApp ni navegador), **no se queda
/// callado**: copia el número y lo dice, para que el conductor pueda llamar o
/// escribir desde otro teléfono.
Future<void> abrirSoporte(BuildContext context, {String? mensaje}) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.https('wa.me', '/${Env.soporteWhatsapp}', {
    if (mensaje != null && mensaje.trim().isNotEmpty) 'text': mensaje.trim(),
  });
  var abierto = false;
  try {
    abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    abierto = false;
  }
  if (abierto) return;
  await Clipboard.setData(ClipboardData(text: soporteLegible()));
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        'No pudimos abrir WhatsApp. Copiamos el número de soporte: '
        '${soporteLegible()}',
      ),
    ),
  );
}

/// "Escríbenos por WhatsApp": la salida para cuando la app dice "contáctanos".
///
/// Había cinco textos que mandaban a "contactar al administrador" y ninguno
/// decía cómo. Un conductor bloqueado, esperando que le confirmen un pago, no
/// tenía a quién preguntarle.
class BotonSoporte extends StatelessWidget {
  const BotonSoporte({
    super.key,
    this.mensaje,
    this.etiqueta = 'Escríbenos por WhatsApp',
    this.compacto = false,
  });

  /// Texto con el que se abre el chat, para que soporte sepa de qué va sin
  /// tener que preguntarlo.
  final String? mensaje;
  final String etiqueta;

  /// Botón de texto, para ir dentro de un párrafo o una tarjeta ya cargada.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    const icono = Icon(Icons.chat_rounded, size: 20);
    void abrir() => abrirSoporte(context, mensaje: mensaje);
    if (compacto) {
      return TextButton.icon(
        onPressed: abrir,
        icon: icono,
        label: Text(etiqueta),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.minTouchTarget,
      child: OutlinedButton.icon(
        onPressed: abrir,
        icon: icono,
        label: Text(etiqueta),
      ),
    );
  }
}

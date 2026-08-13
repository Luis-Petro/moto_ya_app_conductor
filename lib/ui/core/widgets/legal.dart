import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/env.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Abre una URL legal en el navegador del sistema.
///
/// Fuera de la app a propósito: son documentos largos que la gente lee, copia y
/// comparte, y meterlos en un WebView dentro de la app obligaría a mantener una
/// pantalla más y a duplicar el texto. Además así se actualizan publicando la
/// landing, sin sacar una versión nueva de la app.
///
/// Si no se puede abrir —un dispositivo sin navegador, un enlace mal formado—
/// se avisa con la URL a la vista, que es lo único útil que se puede hacer:
/// permite copiarla a mano. Fallar en silencio dejaría al usuario tocando un
/// enlace que no hace nada.
Future<void> abrirEnlaceLegal(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var abierto = false;
  try {
    abierto = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    abierto = false;
  }
  if (!abierto) {
    messenger?.showSnackBar(
      SnackBar(content: Text('No pudimos abrir el enlace. Entra a $url')),
    );
  }
}

/// Enlaces a los documentos legales, para el pie del perfil.
///
/// Van en el perfil y no enterrados en un "Acerca de": las tiendas piden que
/// sean alcanzables desde dentro de la app, y quien los busca los busca aquí.
class EnlacesLegales extends StatelessWidget {
  const EnlacesLegales({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _EnlaceLegal(
          etiqueta: 'Términos y condiciones',
          url: Env.terminosUrl,
        ),
        const Text('·',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 12)),
        _EnlaceLegal(
          etiqueta: 'Política de privacidad',
          url: Env.privacidadUrl,
        ),
      ],
    );
  }
}

class _EnlaceLegal extends StatelessWidget {
  const _EnlaceLegal({required this.etiqueta, required this.url});

  final String etiqueta;
  final String url;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => abrirEnlaceLegal(context, url),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.inkMuted,
      ),
      child: Text(etiqueta, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// Texto de la casilla de aceptación del registro, con los dos documentos
/// enlazados.
///
/// Antes era texto plano: se pedía aceptar unos términos que no se podían leer
/// desde ningún sitio. Una aceptación así no vale gran cosa, ni legalmente ni
/// de cara al usuario.
///
/// Los `TapGestureRecognizer` viven en el `State` y se liberan en `dispose`:
/// creados dentro de `build` se filtrarían en cada repintado, y el registro se
/// repinta con cada tecla que se escribe en el formulario.
class TextoAceptacionLegal extends StatefulWidget {
  const TextoAceptacionLegal({super.key});

  @override
  State<TextoAceptacionLegal> createState() => _TextoAceptacionLegalState();
}

class _TextoAceptacionLegalState extends State<TextoAceptacionLegal> {
  late final TapGestureRecognizer _terminos;
  late final TapGestureRecognizer _privacidad;

  @override
  void initState() {
    super.initState();
    _terminos = TapGestureRecognizer()
      ..onTap = () => abrirEnlaceLegal(context, Env.terminosUrl);
    _privacidad = TapGestureRecognizer()
      ..onTap = () => abrirEnlaceLegal(context, Env.privacidadUrl);
  }

  @override
  void dispose() {
    _terminos.dispose();
    _privacidad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontSize: 13, color: AppColors.ink);
    const enlace = TextStyle(
      fontSize: 13,
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'Acepto los '),
          TextSpan(
            text: 'Términos y condiciones',
            style: enlace,
            recognizer: _terminos,
          ),
          const TextSpan(text: ' y la '),
          TextSpan(
            text: 'Política de privacidad',
            style: enlace,
            recognizer: _privacidad,
          ),
          const TextSpan(text: ' de Zumbeo.'),
        ],
      ),
    );
  }
}

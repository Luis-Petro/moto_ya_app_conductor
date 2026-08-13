import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Confirmación escrita antes de eliminar la cuenta.
///
/// La baja es irreversible y estaba a dos toques. Escribir una palabra no
/// protege de un atacante —de eso ya protege el JWT—, protege del resbalón, que
/// es lo que de verdad pasa. Por eso la palabra vive **en la app** y no en el
/// body del `DELETE`: exigirla en el backend sería una contraseña compartida que
/// quien llama al API a mano teclea igual, y a cambio rompería los clientes que
/// ya existen.
class ConfirmarBajaDialog extends StatefulWidget {
  const ConfirmarBajaDialog({super.key, required this.descripcion});

  /// Qué se borra y qué se conserva, con las palabras de esta app.
  final String descripcion;

  /// Palabra que hay que escribir. Se compara sin tildes ni mayúsculas.
  static const palabra = 'ELIMINAR';

  /// Abre el diálogo dentro del branch del shell (nunca el navigator raíz: allí
  /// el velo negro tapa la pantalla entera).
  static Future<bool> pedir(BuildContext context,
      {required String descripcion}) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => ConfirmarBajaDialog(descripcion: descripcion),
    );
    return ok == true;
  }

  @override
  State<ConfirmarBajaDialog> createState() => _ConfirmarBajaDialogState();
}

class _ConfirmarBajaDialogState extends State<ConfirmarBajaDialog> {
  final _controlador = TextEditingController();
  bool _coincide = false;

  @override
  void initState() {
    super.initState();
    _controlador.addListener(() {
      final coincide = _normalizar(_controlador.text) ==
          _normalizar(ConfirmarBajaDialog.palabra);
      if (coincide != _coincide) {
        setState(() => _coincide = coincide);
      }
    });
  }

  /// Sin espacios sobrantes, sin mayúsculas y sin tildes: quien escribe
  /// "eliminár" en un teclado de celular quiso escribir la palabra.
  String _normalizar(String texto) {
    const con = 'áéíóúÁÉÍÓÚ';
    const sin = 'aeiouAEIOU';
    var t = texto.trim().toLowerCase();
    for (var i = 0; i < con.length; i++) {
      t = t.replaceAll(con[i], sin[i]);
    }
    return t;
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eliminar mi cuenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.descripcion),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Para confirmar, escribe ${ConfirmarBajaDialog.palabra}:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _controlador,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: ConfirmarBajaDialog.palabra),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _coincide ? () => Navigator.pop(context, true) : null,
          child: Text(
            'Eliminar',
            style: TextStyle(
              color: _coincide ? AppColors.danger : AppColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

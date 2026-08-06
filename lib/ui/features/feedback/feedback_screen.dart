import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/services/feedback_service.dart';
import '../../../di/locator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';

/// Queja o sugerencia del cliente. Al enviar, la pantalla agradece de forma
/// explícita: si alguien se toma el trabajo de escribir, lo mínimo es decirle
/// que llegó.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.pedidoId});

  /// Cuando se abre desde un pedido, el feedback queda vinculado a él.
  final int? pedidoId;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _mensaje = TextEditingController();
  final _picker = ImagePicker();

  String _tipo = 'SUGERENCIA';
  File? _captura;
  bool _enviando = false;
  bool _enviado = false;

  @override
  void dispose() {
    _mensaje.dispose();
    super.dispose();
  }

  bool get _valido => _mensaje.text.trim().length >= 10;

  Future<void> _elegirCaptura() async {
    final foto = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxWidth: 1600);
    if (foto == null) return;
    setState(() => _captura = File(foto.path));
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    final res = await locator<FeedbackService>().enviar(
      tipo: _tipo,
      mensaje: _mensaje.text.trim(),
      pedidoId: widget.pedidoId,
      captura: _captura == null
          ? null
          : await dio.MultipartFile.fromFile(_captura!.path),
    );
    if (!mounted) return;
    setState(() => _enviando = false);
    res.when(
      ok: (_) => setState(() => _enviado = true),
      err: (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayúdanos a mejorar')),
      body: SafeArea(
        child: _enviado ? _gracias() : _formulario(),
      ),
    );
  }

  Widget _gracias() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primarySurface,
              child: Icon(Icons.favorite_rounded,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('¡Gracias por escribirnos!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Ya lo estamos leyendo. Lo que nos cuentas es lo que nos dice qué '
              'arreglar primero.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: 'Listo', onPressed: () => context.pop()),
          ],
        ),
      ),
    );
  }

  Widget _formulario() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text('¿Qué nos quieres contar?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Lo leemos nosotros, no un robot. Cuéntanos qué pasó o qué te gustaría '
          'que cambiara.',
          style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
        ),
        const SizedBox(height: AppSpacing.lg),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'SUGERENCIA',
                icon: Icon(Icons.lightbulb_outline),
                label: Text('Sugerencia')),
            ButtonSegment(
                value: 'QUEJA',
                icon: Icon(Icons.report_gmailerrorred_outlined),
                label: Text('Queja')),
          ],
          selected: {_tipo},
          onSelectionChanged: (s) => setState(() => _tipo = s.first),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _mensaje,
          maxLines: 6,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Cuéntanos con tus palabras…',
            alignLabelWithHint: true,
          ),
        ),
        _AdjuntoCaptura(archivo: _captura, onTap: _elegirCaptura),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Enviar',
          icon: Icons.send_rounded,
          loading: _enviando,
          onPressed: _valido ? _enviar : null,
        ),
        if (!_valido)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Text('Escribe al menos 10 caracteres para poder ayudarte.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 12)),
          ),
      ],
    );
  }
}

class _AdjuntoCaptura extends StatelessWidget {
  const _AdjuntoCaptura({required this.archivo, required this.onTap});
  final File? archivo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Icon(
                archivo == null
                    ? Icons.image_outlined
                    : Icons.check_circle_rounded,
                color: archivo == null ? AppColors.inkMuted : AppColors.success),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                archivo == null
                    ? 'Adjuntar una captura (opcional)'
                    : 'Captura lista para enviar',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../di/locator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../router.dart';
import 'alta_conductor_view_model.dart';

/// Alta del perfil de conductor (licencia, vehículo, placa) + documentos.
class AltaConductorScreen extends StatelessWidget {
  const AltaConductorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AltaConductorViewModel(
        locator<ConductorRepository>(),
        locator<LocationService>(),
      )..cargar(),
      child: const _AltaView(),
    );
  }
}

class _AltaView extends StatefulWidget {
  const _AltaView();

  @override
  State<_AltaView> createState() => _AltaViewState();
}

class _AltaViewState extends State<_AltaView> {
  final _licencia = TextEditingController();
  final _vehiculo = TextEditingController();
  final _placa = TextEditingController();
  final _picker = ImagePicker();
  bool _saltoAplicado = false;

  @override
  void dispose() {
    _licencia.dispose();
    _vehiculo.dispose();
    _placa.dispose();
    super.dispose();
  }

  bool _valido(AltaConductorViewModel vm) =>
      _licencia.text.trim().isNotEmpty &&
      _vehiculo.text.trim().isNotEmpty &&
      _placa.text.trim().length >= 5 &&
      vm.tieneCedula;

  Future<void> _guardar(AltaConductorViewModel vm) async {
    if (!_valido(vm)) return;
    final ok = await vm.guardar(
      licencia: _licencia.text.trim(),
      vehiculo: _vehiculo.text.trim(),
      placa: _placa.text.trim().toUpperCase(),
    );
    if (!mounted) return;
    if (ok) {
      context.go(Rutas.inicio);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'No pudimos guardar tu perfil')),
      );
    }
  }

  /// Elige un documento con cámara o galería (no lo sube aún: se sube al guardar).
  Future<void> _elegirDoc(void Function(File) onElegido) async {
    final XFile? foto = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (foto == null) return;
    onElegido(File(foto.path));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AltaConductorViewModel>();

    // Si el perfil ya está completo, saltar directo a Inicio.
    if (!vm.cargando && vm.perfilCompleto && !_saltoAplicado) {
      _saltoAplicado = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Rutas.inicio);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Completa tu perfil')),
      body: SafeArea(
        child: vm.cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  const Text('Datos para conducir',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                      'Necesitamos estos datos para habilitarte a recibir pedidos.',
                      style: TextStyle(color: AppColors.inkMuted)),
                  const SizedBox(height: AppSpacing.xl),
                  const _Label('Número de licencia'),
                  TextField(
                    controller: _licencia,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Ej. 123456789',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _Label('Vehículo'),
                  TextField(
                    controller: _vehiculo,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Ej. Moto Yamaha FZ',
                      prefixIcon: Icon(Icons.two_wheeler_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _Label('Placa'),
                  TextField(
                    controller: _placa,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'ABC-12D',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DocCard(
                    icon: Icons.badge_outlined,
                    titulo: 'Cédula',
                    obligatorio: true,
                    adjuntado: vm.cedula != null,
                    onElegir: () => _elegirDoc(vm.elegirCedula),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DocCard(
                    icon: Icons.two_wheeler_outlined,
                    titulo: 'Papeles de la moto',
                    obligatorio: false,
                    adjuntado: vm.papelesMoto != null,
                    onElegir: () => _elegirDoc(vm.elegirPapelesMoto),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _AvisoRevision(),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Enviar para revisión',
                    loading: vm.guardando,
                    onPressed: _valido(vm) ? () => _guardar(vm) : null,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.inkMuted,
              letterSpacing: 0.4)),
    );
  }
}

/// Tarjeta para adjuntar un documento (cédula/papeles). Marca si es obligatorio
/// y si ya fue adjuntado.
class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.icon,
    required this.titulo,
    required this.obligatorio,
    required this.adjuntado,
    required this.onElegir,
  });

  final IconData icon;
  final String titulo;
  final bool obligatorio;
  final bool adjuntado;
  final VoidCallback onElegir;

  @override
  Widget build(BuildContext context) {
    return MotoCard(
      child: Row(
        children: [
          Icon(adjuntado ? Icons.check_circle : icon,
              color: adjuntado ? AppColors.success : AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(obligatorio ? 'Obligatorio' : 'Opcional',
                    style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: onElegir,
            child: Text(adjuntado ? 'Cambiar' : 'Adjuntar'),
          ),
        ],
      ),
    );
  }
}

/// Aviso de que la cuenta quedará en revisión tras enviar los documentos.
class _AvisoRevision extends StatelessWidget {
  const _AvisoRevision();

  @override
  Widget build(BuildContext context) {
    return MotoCard(
      color: AppColors.primarySurface,
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              'Revisaremos tus documentos y habilitaremos tu cuenta. Te avisaremos cuando puedas empezar a recibir pedidos.',
              style: TextStyle(color: AppColors.ink, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

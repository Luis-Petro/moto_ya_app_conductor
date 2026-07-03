import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/municipio_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../di/locator.dart';
import '../../../domain/models/municipio.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../router.dart';
import 'alta_conductor_view_model.dart';

/// Alta del perfil de conductor (vehículo, placa, licencia opcional) + documentos.
class AltaConductorScreen extends StatelessWidget {
  const AltaConductorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AltaConductorViewModel(
        locator<ConductorRepository>(),
        locator<LocationService>(),
        locator<MunicipioRepository>(),
        locator<UsuarioRepository>(),
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

  bool _valido(AltaConductorViewModel vm) => _faltantes(vm).isEmpty;

  /// Qué le falta al conductor para poder enviar (se muestra bajo el botón).
  List<String> _faltantes(AltaConductorViewModel vm) => [
        if (_vehiculo.text.trim().isEmpty) 'decirnos cuál es tu moto',
        if (_placa.text.trim().length < 5) 'la placa completa',
        if (!vm.tieneCedula) 'la foto de tu cédula',
      ];

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
      if (vm.sesionInvalida) {
        // JWT viejo sin rol CONDUCTOR: cerrar sesión aquí mismo; el router
        // redirige al login y el nuevo JWT ya llega promovido.
        await locator<AuthRepository>().sesionExpirada();
        locator<ConductorRepository>().limpiar();
      }
    }
  }

  /// Foto de la cédula: primero una guía sencilla de cómo tomarla y luego la
  /// cámara (o galería). Pensado para personas poco acostumbradas al celular.
  Future<void> _tomarCedula(AltaConductorViewModel vm) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _GuiaCedulaSheet(),
    );
    if (source == null) return;
    await _capturar(source, vm.elegirCedula);
  }

  /// Papeles de la moto (SOAT / tarjeta de propiedad): elegir cámara o galería.
  Future<void> _tomarPapeles(AltaConductorViewModel vm) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => const _OrigenFotoSheet(
        titulo: 'SOAT o tarjeta de propiedad',
        mensaje: 'Puedes subir uno solo o los dos juntos en una misma foto.',
      ),
    );
    if (source == null) return;
    await _capturar(source, vm.elegirPapelesMoto);
  }

  Future<void> _capturar(ImageSource source, void Function(File) onElegido) async {
    // Calidad/tamaño altos para que los datos del documento se lean bien.
    final XFile? foto = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
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

    final faltantes = _faltantes(vm);

    return Scaffold(
      appBar: AppBar(title: const Text('Completa tu perfil')),
      body: SafeArea(
        child: vm.cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  const Text('Cuéntanos de tu moto',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                      'Con estos datos y la foto de tu cédula quedas en revisión. Te avisamos apenas puedas empezar a trabajar.',
                      style: TextStyle(color: AppColors.inkMuted)),
                  const SizedBox(height: AppSpacing.xl),
                  const _Label('¿Cuál es tu moto?'),
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
                  const _Label('¿En qué municipio trabajas?'),
                  DropdownButtonFormField<Municipio>(
                    value: vm.municipioElegido,
                    items: vm.municipios
                        .map((m) => DropdownMenuItem(
                            value: m, child: Text(m.etiqueta)))
                        .toList(),
                    onChanged: vm.elegirMunicipio,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _Label('Número de licencia (opcional)'),
                  TextField(
                    controller: _licencia,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Ej. 123456789',
                      prefixIcon: Icon(Icons.badge_outlined),
                      helperText:
                          'Por ahora no es obligatoria. Puedes agregarla después.',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text('Tus documentos',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                      'Solo necesitamos una foto de tu cédula. Los demás papeles pueden esperar.',
                      style: TextStyle(color: AppColors.inkMuted)),
                  const SizedBox(height: AppSpacing.md),
                  _DocCard(
                    icon: Icons.badge_outlined,
                    titulo: 'Foto de tu cédula',
                    subtitulo: 'Solo el lado de adelante (donde está tu foto)',
                    etiqueta: 'Necesaria',
                    etiquetaColor: AppColors.primary,
                    archivo: vm.cedula,
                    accion: 'Tomar foto',
                    onElegir: () => _tomarCedula(vm),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DocCard(
                    icon: Icons.description_outlined,
                    titulo: 'SOAT y tarjeta de propiedad',
                    subtitulo:
                        'Por ahora no son obligatorios. Súbelos cuando los tengas a la mano.',
                    etiqueta: 'Opcional por ahora',
                    etiquetaColor: AppColors.inkMuted,
                    archivo: vm.papelesMoto,
                    accion: 'Subir',
                    onElegir: () => _tomarPapeles(vm),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _AvisoRevision(),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: vm.guardando
                        ? 'Enviando tus datos…'
                        : 'Enviar para revisión',
                    loading: vm.guardando,
                    onPressed: _valido(vm) ? () => _guardar(vm) : null,
                  ),
                  if (faltantes.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Te falta: ${faltantes.join(', ')}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.inkMuted, fontSize: 13),
                    ),
                  ],
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

/// Tarjeta para adjuntar un documento. Toda la tarjeta es tocable (área táctil
/// grande) y al tener foto muestra la miniatura con opción de repetirla.
class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.etiqueta,
    required this.etiquetaColor,
    required this.archivo,
    required this.accion,
    required this.onElegir,
  });

  final IconData icon;
  final String titulo;
  final String subtitulo;
  final String etiqueta;
  final Color etiquetaColor;
  final File? archivo;
  final String accion;
  final VoidCallback onElegir;

  @override
  Widget build(BuildContext context) {
    final adjuntado = archivo != null;
    return MotoCard(
      onTap: onElegir,
      borderColor: adjuntado ? AppColors.success : null,
      child: Row(
        children: [
          if (adjuntado)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Image.file(archivo!,
                  width: 56, height: 56, fit: BoxFit.cover),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitulo,
                    style: const TextStyle(
                        color: AppColors.inkMuted, fontSize: 12.5)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (adjuntado) ...[
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 16),
                      const SizedBox(width: 4),
                      const Text('Foto lista',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ] else
                      Text(etiqueta,
                          style: TextStyle(
                              color: etiquetaColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: onElegir,
            child: Text(adjuntado ? 'Repetir' : accion),
          ),
        ],
      ),
    );
  }
}

/// Guía paso a paso para la foto de la cédula, en lenguaje sencillo.
/// Devuelve la fuente elegida (cámara o galería) o null si cancela.
class _GuiaCedulaSheet extends StatelessWidget {
  const _GuiaCedulaSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Foto de tu cédula',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            const Text(
                'Solo el lado de adelante, donde está tu foto. Sigue estos pasos:',
                style: TextStyle(color: AppColors.inkMuted)),
            const SizedBox(height: AppSpacing.lg),
            const _PasoGuia(
              numero: '1',
              icon: Icons.table_bar_outlined,
              texto: 'Pon la cédula sobre una mesa o superficie plana.',
            ),
            const _PasoGuia(
              numero: '2',
              icon: Icons.wb_sunny_outlined,
              texto: 'Busca buena luz, sin sombras ni reflejos encima.',
            ),
            const _PasoGuia(
              numero: '3',
              icon: Icons.zoom_in_rounded,
              texto:
                  'Acerca el celular hasta que los nombres y números se lean claros.',
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Abrir la cámara',
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: const Text('Ya tengo la foto en mi celular'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasoGuia extends StatelessWidget {
  const _PasoGuia({
    required this.numero,
    required this.icon,
    required this.texto,
  });

  final String numero;
  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text('$numero. $texto',
                style: const TextStyle(fontSize: 14.5, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

/// Selector simple de origen de la foto (cámara o galería) para documentos
/// opcionales.
class _OrigenFotoSheet extends StatelessWidget {
  const _OrigenFotoSheet({required this.titulo, required this.mensaje});

  final String titulo;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            Text(mensaje, style: const TextStyle(color: AppColors.inkMuted)),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Tomar una foto',
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: const Text('Elegir de la galería'),
            ),
          ],
        ),
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

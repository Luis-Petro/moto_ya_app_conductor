import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/pedido_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/tracking_service.dart';
import '../../../di/locator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../../domain/models/estado_pedido.dart';
import 'pedido_activo_view_model.dart';

class PedidoActivoScreen extends StatelessWidget {
  const PedidoActivoScreen({super.key, required this.pedidoId});
  final int pedidoId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PedidoActivoViewModel(
        locator<PedidoRepository>(),
        locator<TrackingService>(),
        pedidoId,
      )..cargar(),
      child: const _ActivoView(),
    );
  }
}

class _ActivoView extends StatefulWidget {
  const _ActivoView();

  @override
  State<_ActivoView> createState() => _ActivoViewState();
}

class _ActivoViewState extends State<_ActivoView> {
  final _picker = ImagePicker();
  File? _evidencia;

  Future<void> _tomarEvidencia() async {
    final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
    if (foto == null) return;
    setState(() => _evidencia = File(foto.path));
  }

  Future<void> _llamar(String telefono) async {
    final uri = Uri(scheme: 'tel', path: telefono);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _accion(PedidoActivoViewModel vm) async {
    final esEntrega = vm.proximoEstado == EstadoPedido.entregado;
    final ok = esEntrega ? await vm.entregar(foto: _evidencia) : await vm.avanzar();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'No pudimos actualizar el estado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PedidoActivoViewModel>();

    if (vm.cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (vm.pedido == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorRetry(
            message: vm.error ?? 'No pudimos cargar el pedido',
            onRetry: vm.cargar),
      );
    }
    if (vm.entregado) return _Entregado(vm: vm);

    final pedido = vm.pedido!;
    final centro = pedido.destino ?? vm.posicion ?? LocationService.fallbackCenter;

    return Scaffold(
      appBar: AppBar(title: Text('Pedido #${pedido.id}')),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            child: FlutterMap(
              options: MapOptions(initialCenter: centro, initialZoom: 15),
              children: [
                osmTileLayer(),
                MarkerLayer(markers: [
                  if (pedido.destino != null)
                    pinMarker(pedido.destino!, icon: Icons.location_on),
                  if (vm.posicion != null) usuarioMarker(vm.posicion!),
                ]),
                osmAttribution(),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                MotoCard(
                  child: Row(
                    children: [
                      InitialsAvatar(
                          initials: _iniciales(pedido.clienteNombre), radius: 20),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pedido.clienteNombre ?? 'Cliente',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(pedido.direccionDestino ?? '—',
                                style: const TextStyle(
                                    color: AppColors.inkMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (pedido.clienteTelefono != null)
                        IconButton.filledTonal(
                          onPressed: () => _llamar(pedido.clienteTelefono!),
                          icon: const Icon(Icons.phone),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _PasosVerticales(estado: vm.estado),
                const SizedBox(height: AppSpacing.lg),
                _BotonEvidencia(
                  archivo: _evidencia,
                  onTap: _tomarEvidencia,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: PrimaryButton(
              label: vm.etiquetaAvance,
              icon: vm.proximoEstado == EstadoPedido.entregado
                  ? Icons.check_circle_outline
                  : Icons.arrow_forward_rounded,
              loading: vm.procesando,
              onPressed: vm.proximoEstado == null ? null : () => _accion(vm),
            ),
          ),
        ],
      ),
    );
  }

  String _iniciales(String? nombre) {
    if (nombre == null || nombre.trim().isEmpty) return 'C';
    final p = nombre.trim().split(RegExp(r'\s+'));
    if (p.length == 1) return p.first[0].toUpperCase();
    return (p.first[0] + p.last[0]).toUpperCase();
  }
}

class _PasosVerticales extends StatelessWidget {
  const _PasosVerticales({required this.estado});
  final EstadoPedido estado;

  @override
  Widget build(BuildContext context) {
    const pasos = [
      EstadoPedido.enCompra,
      EstadoPedido.enCamino,
      EstadoPedido.entregado,
    ];
    final actual = estado.indiceTracking;
    return MotoCard(
      child: Column(
        children: [
          for (final paso in pasos) _fila(paso, paso.indiceTracking <= actual,
              paso.indiceTracking == actual),
        ],
      ),
    );
  }

  Widget _fila(EstadoPedido paso, bool hecho, bool actual) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            hecho
                ? Icons.check_circle_rounded
                : (actual ? Icons.radio_button_checked : Icons.circle_outlined),
            color: hecho || actual ? AppColors.success : AppColors.line,
          ),
          const SizedBox(width: AppSpacing.md),
          Text(paso.label,
              style: TextStyle(
                  fontWeight: actual ? FontWeight.w700 : FontWeight.w500,
                  color: hecho || actual ? AppColors.ink : AppColors.inkMuted)),
        ],
      ),
    );
  }
}

class _BotonEvidencia extends StatelessWidget {
  const _BotonEvidencia({required this.archivo, required this.onTap});
  final File? archivo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Icon(archivo == null ? Icons.photo_camera_outlined : Icons.check_circle,
                color: archivo == null ? AppColors.inkMuted : AppColors.success),
            const SizedBox(width: AppSpacing.md),
            Text(archivo == null
                ? 'Subir foto de evidencia'
                : 'Foto lista para enviar'),
          ],
        ),
      ),
    );
  }
}

class _Entregado extends StatelessWidget {
  const _Entregado({required this.vm});
  final PedidoActivoViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primarySurface,
                  child: Icon(Icons.check_rounded,
                      size: 44, color: AppColors.success),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('¡Pedido entregado!',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.sm),
                const Text('La comisión se registró en tu billetera.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkMuted)),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Volver al inicio',
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

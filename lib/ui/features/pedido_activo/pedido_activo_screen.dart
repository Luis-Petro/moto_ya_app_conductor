import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:latlong2/latlong.dart';

import '../../../data/repositories/pedido_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/tracking_service.dart';
import '../../../di/locator.dart';
import '../../core/format/formato.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../../domain/models/estado_pedido.dart';
import '../../../domain/models/pedido.dart';
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

  /// Abre la navegación guiada en Google Maps hacia el punto indicado (nuestro
  /// mapa OSM no ofrece turn-by-turn; Maps sí, y todo conductor lo tiene).
  Future<void> _comoLlegar(LatLng punto) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${punto.latitude},${punto.longitude}&travelmode=driving');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos abrir Google Maps')),
      );
    }
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
    final centro =
        vm.puntoObjetivo ?? vm.posicion ?? LocationService.fallbackCenter;

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
                  if (pedido.origen != null)
                    pinMarker(pedido.origen!,
                        icon: Icons.storefront, color: AppColors.accent),
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
                // Cómo llegar: abre navegación guiada en Google Maps hacia el
                // objetivo actual (recogida antes de EN_CAMINO, entrega después).
                if (vm.puntoObjetivo != null) ...[
                  SizedBox(
                    height: AppSpacing.minTouchTarget,
                    child: OutlinedButton.icon(
                      onPressed: () => _comoLlegar(vm.puntoObjetivo!),
                      icon: const Icon(Icons.navigation_rounded),
                      label: Text('Cómo llegar al ${vm.etiquetaObjetivo}'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
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
                _DetallePedido(pedido: pedido),
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

/// Detalle completo del pedido: qué es, dónde se recoge y entrega (con
/// referencias), compra a adelantar, ganancia y foto adjunta si la hay.
class _DetallePedido extends StatelessWidget {
  const _DetallePedido({required this.pedido});
  final Pedido pedido;

  void _verFoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tarifa = pedido.tarifaFinal ?? pedido.tarifaSugerida;
    return MotoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(pedido.categoria.icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(pedido.categoria.label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(pedido.descripcion,
              style: const TextStyle(fontSize: 15, height: 1.35)),
          const Divider(height: AppSpacing.xl),
          _PuntoFila(
            icon: Icons.storefront,
            color: AppColors.accent,
            titulo: 'Recogida / compra',
            direccion: pedido.direccionRecogida,
          ),
          const SizedBox(height: AppSpacing.md),
          _PuntoFila(
            icon: Icons.location_on,
            color: AppColors.primary,
            titulo: 'Entrega',
            direccion: pedido.direccionDestino,
            referencia: pedido.referencia,
          ),
          if (pedido.requiereCompra) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      pedido.montoCompraEstimado != null
                          ? 'Debes comprar por ~${Formato.moneda(pedido.montoCompraEstimado)}. El cliente te lo devuelve en la entrega.'
                          : 'Este pedido incluye una compra que el cliente te devuelve en la entrega.',
                      style: const TextStyle(fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (tarifa != null) ...[
            const Divider(height: AppSpacing.xl),
            Row(
              children: [
                const Text('Servicio',
                    style: TextStyle(color: AppColors.inkMuted)),
                const Spacer(),
                Text(Formato.moneda(tarifa),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Tu ganancia',
                    style: TextStyle(color: AppColors.inkMuted)),
                const Spacer(),
                Text(Formato.moneda(Pedido.gananciaNeta(tarifa)),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.success)),
              ],
            ),
          ],
          if (pedido.fotoUrl != null && pedido.fotoUrl!.isNotEmpty) ...[
            const Divider(height: AppSpacing.xl),
            const Text('FOTO DEL PEDIDO',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                    letterSpacing: 0.4)),
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () => _verFoto(context, pedido.fotoUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Image.network(
                  pedido.fotoUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    alignment: Alignment.center,
                    color: AppColors.background,
                    child: const Text('No pudimos cargar la foto',
                        style: TextStyle(
                            color: AppColors.inkMuted, fontSize: 12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Toca la foto para ampliarla',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}

/// Fila de un punto del recorrido (recogida o entrega) con su referencia.
class _PuntoFila extends StatelessWidget {
  const _PuntoFila({
    required this.icon,
    required this.color,
    required this.titulo,
    required this.direccion,
    this.referencia,
  });

  final IconData icon;
  final Color color;
  final String titulo;
  final String? direccion;
  final String? referencia;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted)),
              Text(direccion ?? 'Ubicación marcada en el mapa',
                  style: const TextStyle(fontSize: 14, height: 1.3)),
              if (referencia != null && referencia!.trim().isNotEmpty)
                Text('Referencia: ${referencia!}',
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkMuted,
                        height: 1.3)),
            ],
          ),
        ),
      ],
    );
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:latlong2/latlong.dart';

import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
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
import '../../core/widgets/proponer_lugar_sheet.dart';
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
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (foto == null) return;
    setState(() => _evidencia = File(foto.path));
  }

  /// Si el dispositivo puede abrir `wa.me`. Se resuelve una vez al entrar: sin
  /// WhatsApp instalado el botón no se pinta, en vez de abrir un navegador con
  /// una página que no lleva a ninguna conversación.
  bool _whatsappDisponible = false;

  @override
  void initState() {
    super.initState();
    _resolverWhatsapp();
  }

  Future<void> _resolverWhatsapp() async {
    final puede = await canLaunchUrl(Uri.parse('https://wa.me/573000000000'));
    if (mounted) setState(() => _whatsappDisponible = puede);
  }

  bool _tieneTelefono(Pedido p) =>
      p.clienteTelefono != null && p.clienteTelefono!.trim().isNotEmpty;

  Future<void> _llamar(String telefono) async {
    final uri = Uri(scheme: 'tel', path: telefono);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Abre el chat de WhatsApp con el cliente. `wa.me` exige el número sin `+`
  /// ni separadores; si viene local (10 dígitos) se le antepone el indicativo
  /// de Colombia, que es donde opera la plataforma.
  Future<void> _escribirWhatsapp(String telefono) async {
    var num = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (num.length == 10) num = '57$num';
    final uri = Uri.parse('https://wa.me/$num');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Abre la navegación guiada en Google Maps hacia el punto indicado (nuestro
  /// mapa OSM no ofrece turn-by-turn; Maps sí). Los esquemas `google.navigation:`
  /// (Android) y `comgooglemaps://` (iOS) SOLO los resuelve la app instalada, así
  /// que `canLaunchUrl` nos dice si el conductor la tiene; si no, le ofrecemos
  /// instalarla (o abrirla en el navegador como salida).
  Future<void> _comoLlegar(LatLng punto) async {
    final destino = '${punto.latitude},${punto.longitude}';
    final appUri = Platform.isIOS
        ? Uri.parse('comgooglemaps://?daddr=$destino&directionsmode=driving')
        : Uri.parse('google.navigation:q=$destino&mode=d');

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
      return;
    }
    if (mounted) await _ofrecerInstalarMaps(destino);
  }

  /// Google Maps no está instalado: ofrece ir a la tienda o, como salida, abrir
  /// la ruta en el navegador (así el conductor nunca queda sin cómo llegar).
  Future<void> _ofrecerInstalarMaps(String destino) async {
    final store = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/app/google-maps/id585027354')
        : Uri.parse('market://details?id=com.google.android.apps.maps');
    final storeWeb = Uri.parse(
      Platform.isIOS
          ? 'https://apps.apple.com/app/google-maps/id585027354'
          : 'https://play.google.com/store/apps/details?id=com.google.android.apps.maps',
    );
    final web = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destino&travelmode=driving',
    );

    // pedido_activo se abre sobre el navigator raíz: showDialog por defecto es
    // correcto aquí (no aplica el gotcha de tabs).
    final accion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Google Maps no está instalado'),
        content: const Text(
          'Instala Google Maps para la navegación guiada, o abre la ruta en '
          'el navegador.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('navegador'),
            child: const Text('Abrir en el navegador'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('instalar'),
            child: const Text('Instalar'),
          ),
        ],
      ),
    );
    if (accion == 'instalar') {
      if (!await launchUrl(store, mode: LaunchMode.externalApplication)) {
        await launchUrl(storeWeb, mode: LaunchMode.externalApplication);
      }
    } else if (accion == 'navegador') {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _accion(PedidoActivoViewModel vm) async {
    final esEntrega = vm.proximoEstado == EstadoPedido.entregado;
    final ok = esEntrega
        ? await vm.entregar(foto: _evidencia)
        : await vm.avanzar();
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
          onRetry: vm.cargar,
        ),
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
          // Mapa más bajo que antes: lo que el conductor necesita a la vista es
          // a quién llamar, dónde recoger/entregar y cuánto gana; el mapa es
          // referencia (la navegación real la hace "Cómo llegar").
          SizedBox(
            height: 150,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: centro,
                initialZoom: 15,
                minZoom: zoomMinimoMapa,
                maxZoom: zoomMaximoMapa,
              ),
              children: [
                osmTileLayer(),
                MarkerLayer(
                  markers: [
                    if (pedido.origen != null)
                      pinMarker(
                        pedido.origen!,
                        icon: Icons.storefront,
                        color: AppColors.accent,
                      ),
                    if (pedido.destino != null)
                      pinMarker(pedido.destino!, icon: Icons.location_on),
                    if (vm.posicion != null) usuarioMarker(vm.posicion!),
                  ],
                ),
                osmAttribution(),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _EstadoCompacto(estado: vm.estado),
                const SizedBox(height: AppSpacing.md),
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
                  const SizedBox(height: AppSpacing.md),
                ],
                MotoCard(
                  child: Row(
                    children: [
                      InitialsAvatar(
                        initials: _iniciales(pedido.clienteNombre),
                        imageUrl: pedido.clienteFotoUrl,
                        radius: 20,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pedido.clienteNombre ?? 'Cliente',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              pedido.direccionDestino ?? '—',
                              style: const TextStyle(
                                color: AppColors.inkMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Sin teléfono en el detalle no hay a quién llamar: se
                      // ocultan las acciones en vez de dejar botones muertos.
                      if (_tieneTelefono(pedido)) ...[
                        if (_whatsappDisponible)
                          IconButton.filledTonal(
                            tooltip: 'Escribir por WhatsApp',
                            onPressed: () =>
                                _escribirWhatsapp(pedido.clienteTelefono!),
                            icon: const Icon(Icons.chat_outlined),
                          ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton.filledTonal(
                          tooltip: 'Llamar',
                          onPressed: () => _llamar(pedido.clienteTelefono!),
                          icon: const Icon(Icons.phone),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ResumenRuta(pedido: pedido),
                const SizedBox(height: AppSpacing.md),
                // Lo largo (descripción, compra, foto) queda plegado: se abre
                // cuando hace falta, no ocupa la pantalla del pedido en curso.
                _PanelDetalle(pedido: pedido),
                // La evidencia solo importa en el último tramo.
                if (vm.proximoEstado == EstadoPedido.entregado) ...[
                  const SizedBox(height: AppSpacing.md),
                  _BotonEvidencia(archivo: _evidencia, onTap: _tomarEvidencia),
                ],
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

/// Estado del pedido en una sola línea (antes eran tres filas verticales que
/// empujaban la ganancia y la ruta fuera de la pantalla).
class _EstadoCompacto extends StatelessWidget {
  const _EstadoCompacto({required this.estado});
  final EstadoPedido estado;

  @override
  Widget build(BuildContext context) {
    const pasos = [
      EstadoPedido.enCompra,
      EstadoPedido.enCamino,
      EstadoPedido.entregado,
    ];
    final actual = estado.indiceTracking;
    return Row(
      children: [
        for (final paso in pasos) ...[
          Icon(
            paso.indiceTracking < actual
                ? Icons.check_circle_rounded
                : (paso.indiceTracking == actual
                      ? Icons.radio_button_checked
                      : Icons.circle_outlined),
            size: 18,
            color: paso.indiceTracking <= actual
                ? AppColors.success
                : AppColors.line,
          ),
          const SizedBox(width: 4),
          Text(
            paso.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: paso.indiceTracking == actual
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: paso.indiceTracking <= actual
                  ? AppColors.ink
                  : AppColors.inkMuted,
            ),
          ),
          if (paso != pasos.last)
            const Expanded(child: Divider(indent: 6, endIndent: 6)),
        ],
      ],
    );
  }
}

/// Lo que el conductor mira mientras trabaja: dónde recoge, dónde entrega y
/// cuánto le queda. Siempre visible, sin scroll.
class _ResumenRuta extends StatelessWidget {
  const _ResumenRuta({required this.pedido});
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final tarifa = pedido.tarifaFinal ?? pedido.tarifaSugerida;
    return MotoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PuntoFila(
            icon: Icons.storefront,
            color: AppColors.accent,
            titulo: 'Recogida / compra',
            direccion: pedido.direccionRecogida,
            referencia: pedido.referenciaRecogida,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PuntoFila(
            icon: Icons.location_on,
            color: AppColors.primary,
            titulo: 'Entrega',
            direccion: pedido.direccionDestino,
            referencia: pedido.referencia,
          ),
          if (tarifa != null) ...[
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                const Text(
                  'Tu ganancia',
                  style: TextStyle(color: AppColors.inkMuted),
                ),
                const Spacer(),
                Text(
                  Formato.moneda(Pedido.gananciaNeta(tarifa)),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Panel plegable con el detalle largo del pedido.
class _PanelDetalle extends StatelessWidget {
  const _PanelDetalle({required this.pedido});
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.line),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          title: const Text(
            'Ver todo el detalle',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [_DetallePedido(pedido: pedido)],
        ),
      ),
    );
  }
}

/// Detalle largo del pedido: qué es, compra a adelantar, desglose del servicio y
/// foto adjunta si la hay. Los puntos y la ganancia van arriba, en `_ResumenRuta`.
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
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(pedido.categoria.icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              pedido.categoria.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          pedido.descripcion,
          style: const TextStyle(fontSize: 15, height: 1.35),
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
                const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
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
              const Text(
                'Servicio',
                style: TextStyle(color: AppColors.inkMuted),
              ),
              const Spacer(),
              Text(
                Formato.moneda(tarifa),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                'Comisión de la plataforma (15%)',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '−${Formato.moneda(Pedido.comision(tarifa))}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ],
        if (pedido.fotoUrl != null && pedido.fotoUrl!.isNotEmpty) ...[
          const Divider(height: AppSpacing.xl),
          const Text(
            'FOTO DEL PEDIDO',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.inkMuted,
              letterSpacing: 0.4,
            ),
          ),
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
                  child: const Text(
                    'No pudimos cargar la foto',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toca la foto para ampliarla',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 11.5),
          ),
        ],
      ],
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
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted,
                ),
              ),
              Text(
                direccion ?? 'Ubicación marcada en el mapa',
                style: const TextStyle(fontSize: 14, height: 1.3),
              ),
              if (referencia != null && referencia!.trim().isNotEmpty)
                Text(
                  'Referencia: ${referencia!}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkMuted,
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ),
      ],
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
            Icon(
              archivo == null
                  ? Icons.photo_camera_outlined
                  : Icons.check_circle,
              color: archivo == null ? AppColors.inkMuted : AppColors.success,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              archivo == null
                  ? 'Subir foto de evidencia'
                  : 'Foto lista para enviar',
            ),
          ],
        ),
      ),
    );
  }
}

/// Acción secundaria de la pantalla de entrega: aportar el punto al catálogo.
///
/// Deliberadamente discreta (no compite con "Volver al inicio") y con
/// confirmación explícita al enviar: si alguien se toma el trabajo de aportar,
/// lo mínimo es decirle que llegó — mismo criterio que el agradecimiento del
/// feedback.
class _GuardarLugar extends StatefulWidget {
  const _GuardarLugar({required this.punto});
  final LatLng punto;

  @override
  State<_GuardarLugar> createState() => _GuardarLugarState();
}

class _GuardarLugarState extends State<_GuardarLugar> {
  bool _guardado = false;

  Future<void> _abrir() async {
    final ok = await mostrarProponerLugar(
      context,
      punto: widget.punto,
      municipioId: locator<UsuarioRepository>().enCache?.municipioId,
    );
    if (!mounted || ok != true) return;
    setState(() => _guardado = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '¡Gracias! Lo revisamos y queda disponible para los clientes.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_guardado) {
      return const Text(
        'Lugar enviado para revisión ✓',
        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
      );
    }
    return TextButton.icon(
      onPressed: _abrir,
      icon: const Icon(Icons.add_location_alt_outlined),
      label: const Text('Guardar este sitio en el mapa'),
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
                  child: Icon(
                    Icons.check_rounded,
                    size: 44,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  '¡Pedido entregado!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'La comisión se registró en tu billetera.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Volver al inicio',
                  onPressed: () => context.pop(),
                ),
                // Justo aquí el conductor acaba de estar en la puerta: es el
                // único momento en que sabe con certeza dónde queda el sitio.
                if (vm.pedido?.destino case final LatLng destino) ...[
                  const SizedBox(height: AppSpacing.md),
                  _GuardarLugar(punto: destino),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

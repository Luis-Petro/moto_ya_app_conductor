import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:latlong2/latlong.dart';

import '../../../data/models/polyline_codec.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../data/services/imagen_compresor.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/tracking_service.dart';
import '../../../di/locator.dart';
import '../../core/format/formato.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/encabezado.dart';
import '../../core/widgets/lugares_layer.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/proponer_lugar_sheet.dart';
import '../../core/widgets/visor_foto.dart';
import '../../router.dart';
import '../../../domain/models/estado_pedido.dart';
import '../../../domain/models/pedido.dart';
import 'mapa_pedido_screen.dart';
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
  static const _compresor = ImagenCompresor();

  File? _evidencia;
  int? _pesoEvidencia;

  /// La entrega falló con la foto ya tomada. La foto **no** se pierde: el botón
  /// pasa a reintentar el envío y no se vuelve a abrir la cámara.
  bool _falloConFoto = false;

  Future<void> _tomarEvidencia() async {
    // 1280 px y calidad 55 al capturar: una foto de entrega es la prueba de que
    // el paquete llegó, no un documento que haya que leer. Se sube por datos
    // móviles, desde la calle y con el cliente delante.
    final XFile? foto = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 55,
      maxWidth: 1280,
    );
    if (foto == null) return;

    // Segunda pasada al tope de peso: la misma configuración de captura da 180 KB
    // en un teléfono y 900 KB en otro con mejor sensor. Si falla, se queda el
    // original — comprimir es una mejora, no un requisito de la entrega.
    final archivo = await _compresor.aTope(File(foto.path));
    final peso = await archivo.length();
    if (!mounted) return;
    setState(() {
      _evidencia = archivo;
      _pesoEvidencia = peso;
      _falloConFoto = false;
    });
  }

  void _descartarEvidencia() {
    setState(() {
      _evidencia = null;
      _pesoEvidencia = null;
      _falloConFoto = false;
    });
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
    // Doble toque: el botón ya se deshabilita con `procesando`, pero la guarda
    // aquí cierra la ventana entre el toque y el primer rebuild. Dos entregas
    // significan dos subidas de la misma foto y dos avances de estado.
    if (vm.procesando) return;

    final esEntrega = vm.proximoEstado == EstadoPedido.entregado;
    final ok = esEntrega
        ? await vm.entregar(foto: _evidencia)
        : await vm.avanzar();
    if (!mounted) return;

    if (!ok) {
      // Con foto, el fallo no cuesta repetirla: el pedido no avanzó y el archivo
      // sigue en `_evidencia`, listo para reenviarse.
      if (esEntrega && _evidencia != null) {
        setState(() => _falloConFoto = true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            esEntrega && _evidencia != null
                ? '${vm.error ?? 'No pudimos enviar la evidencia'} La foto sigue '
                      'guardada: toca "Reintentar envío".'
                : (vm.error ?? 'No pudimos actualizar el estado'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PedidoActivoViewModel>();

    if (vm.cargando) {
      return const Scaffold(body: CargandoConMensaje('Cargando tu pedido…'));
    }
    if (vm.pedido == null) {
      return Scaffold(
        appBar: encabezado(null, onAtras: () => context.go(Rutas.inicio)),
        body: ErrorRetry(
          message: vm.error ?? 'No pudimos cargar el pedido',
          onRetry: vm.cargar,
          esRed: vm.errorEsRed,
        ),
      );
    }
    if (vm.entregado) return _Entregado(vm: vm);

    final pedido = vm.pedido!;
    // Trayecto recogida→entrega tal como lo calculó el backend. Esta pantalla no lo
    // dibujaba: el mapa eran dos pines sueltos y el conductor no podía ver por dónde
    // va el viaje sin salir a "Cómo llegar".
    final ruta = PolylineCodec.decode(pedido.rutaPolyline);

    return Scaffold(
      // Retroceso explícito: a esta pantalla se llega desde una notificación,
      // que reemplaza la pila, y `AppBar()` sola dejaría al conductor sin salida
      // visible en mitad de un pedido.
      appBar: encabezado('Pedido #${pedido.id}',
          onAtras: () => context.go(Rutas.inicio)),
      body: Column(
        children: [
          // Mapa más bajo que antes: lo que el conductor necesita a la vista es
          // a quién llamar, dónde recoger/entregar y cuánto gana; el mapa es
          // referencia (la navegación real la hace "Cómo llegar"). Y cuando esa
          // referencia no basta, un toque lo abre entero.
          _MapaResumen(
            pedido: pedido,
            ruta: ruta,
            posicion: vm.posicion,
            objetivo: vm.puntoObjetivo,
            onAmpliar: () => abrirMapaDelPedido(
              context,
              vm,
              onComoLlegar: _comoLlegar,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.subtitle,
                            ),
                            Text(
                              pedido.direccionDestino ?? '—',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption,
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
                  _BotonEvidencia(
                    archivo: _evidencia,
                    onTap: _tomarEvidencia,
                    onDescartar: _descartarEvidencia,
                    pesoBytes: _pesoEvidencia,
                    progreso: vm.progresoSubida,
                    subiendo: vm.procesando && _evidencia != null,
                    falloEnvio: _falloConFoto,
                  ),
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
              // Tras un fallo con la foto ya tomada, el botón dice qué va a
              // hacer: reenviar lo que ya está, no volver a empezar.
              label: _falloConFoto ? 'Reintentar envío' : vm.etiquetaAvance,
              icon: _falloConFoto
                  ? Icons.refresh_rounded
                  : (vm.proximoEstado == EstadoPedido.entregado
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward_rounded),
              loading: vm.procesando,
              onPressed: vm.proximoEstado == null || vm.procesando
                  ? null
                  : () => _accion(vm),
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

/// La franja de mapa del pedido en curso: un vistazo, y la puerta al mapa entero.
///
/// **No se maneja, se mira.** La interacción va apagada (`InteractiveFlag.none`)
/// y el toque abre [MapaPedidoScreen]. No es quitar una capacidad, es cambiarla
/// por otra mayor, y resuelve tres cosas de golpe:
///
/// - El encuadre inicial se aplica **una sola vez** (así funciona
///   `initialCameraFit`). Un arrastre accidental —fácil, porque el dedo pasa por
///   encima al desplazar la ficha— dejaba la franja encuadrada en un descampado
///   sin ninguna forma de volver.
/// - Arrastrar sobre el mapa robaba el gesto de desplazar la lista de abajo: el
///   conductor creía que la pantalla se había colgado.
/// - En 150 px no se puede acercar a nada útil. Lo que hace falta cuando el mapa
///   no basta no es un mapa un poco más grande: es el mapa entero.
///
/// A cambio, toda la franja es un objetivo táctil de 150 px de alto, que es lo
/// más forgiving que se puede ofrecer a alguien que acaba de parar la moto.
class _MapaResumen extends StatefulWidget {
  const _MapaResumen({
    required this.pedido,
    required this.ruta,
    required this.posicion,
    required this.objetivo,
    required this.onAmpliar,
  });

  final Pedido pedido;
  final List<LatLng> ruta;
  final LatLng? posicion;
  final LatLng? objetivo;
  final VoidCallback onAmpliar;

  @override
  State<_MapaResumen> createState() => _MapaResumenState();
}

class _MapaResumenState extends State<_MapaResumen> {
  static const double _alto = 150;

  final _mapa = MapController();

  /// El mapa ya se pintó una vez: `camera` y `fitCamera` lanzan antes de eso.
  bool _listo = false;

  void _alEstarListo() {
    _listo = true;
  }

  @override
  void dispose() {
    // `FlutterMap` solo desecha el controlador cuando lo creó él. Este es
    // nuestro, y por dentro es un `ValueNotifier` con un `StreamController` de
    // eventos.
    _mapa.dispose();
    super.dispose();
  }

  List<LatLng> get _puntos => [
        ...widget.ruta,
        if (widget.pedido.origen != null) widget.pedido.origen!,
        if (widget.pedido.destino != null) widget.pedido.destino!,
        if (widget.posicion != null) widget.posicion!,
      ];

  @override
  void didUpdateWidget(covariant _MapaResumen anterior) {
    super.didUpdateWidget(anterior);
    if (!_listo) return;

    // Se reencuadra por **dos hechos**, no por cada latido del GPS. La posición
    // llega cada pocos segundos: reencuadrar en cada una haría saltar el mapa
    // mientras se lee, y un mapa que se mueve solo se deja de mirar.
    //
    // 1. Cambió el objetivo (se marcó "En camino"): la franja estaba encuadrada
    //    en el tramo anterior.
    // 2. El punto del conductor se salió de lo que se ve. Sin esto la franja
    //    envejece sola: se avanza tres cuadras y el propio punto ya no está en
    //    pantalla, sin nada que lo anuncie ni forma de recuperarlo.
    final cambioObjetivo = widget.objetivo != anterior.objetivo;
    final seSalioDeCuadro = widget.posicion != null &&
        !_mapa.camera.visibleBounds.contains(widget.posicion!);
    if (cambioObjetivo || seSalioDeCuadro) {
      final puntos = _puntos;
      if (puntos.length < 2) return;
      // Fuera del `build`: `fitCamera` mueve la cámara y notifica, y hacerlo en
      // mitad de la construcción del árbol es un setState durante el build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _listo) {
          _mapa.fitCamera(
            encuadreDePuntos(puntos, padding: const EdgeInsets.all(16)),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    final puntos = _puntos;

    return SizedBox(
      height: _alto,
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapa,
              options: MapOptions(
                initialCenter: widget.objetivo ??
                    widget.posicion ??
                    LocationService.fallbackCenter,
                initialZoom: 15,
                // Encuadre que abarca ruta y pines. Con zoom fijo, un trayecto
                // que no cabe en 150 px de alto deja la mitad fuera de pantalla
                // sin que nada lo indique.
                initialCameraFit: puntos.length >= 2
                    ? encuadreDePuntos(puntos,
                        padding: const EdgeInsets.all(16))
                    : null,
                minZoom: zoomMinimoMapa,
                maxZoom: zoomMaximoMapa,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
                onMapReady: _alEstarListo,
              ),
              children: [
                osmTileLayer(),
                // Sin nombres: en 150 px de alto las etiquetas taparían los
                // pines de recogida y entrega, que son el objetivo del viaje.
                // Con nombres se ven al ampliar, que es donde hay sitio.
                const LugaresLayer(mostrarNombres: false),
                if (widget.ruta.length >= 2)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: widget.ruta,
                      strokeWidth: 4,
                      color: AppColors.primary,
                      borderStrokeWidth: 1,
                      borderColor: AppColors.surface,
                    ),
                  ]),
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
                    if (widget.posicion != null) usuarioMarker(widget.posicion!),
                  ],
                ),
                osmAttribution(),
              ],
            ),
          ),
          Positioned.fill(
            child: Semantics(
              // `container: true`: sin él el nodo se funde con lo que tiene
              // alrededor y el lector de pantalla anuncia el mapa como parte de
              // la ficha del pedido, sin decir que se puede abrir.
              container: true,
              button: true,
              label: 'Ampliar el mapa del pedido',
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: widget.onAmpliar),
              ),
            ),
          ),
          // Un mapa que se toca sin nada que lo diga es una función que no
          // existe. La pastilla va abajo a la izquierda: la atribución de
          // OpenStreetMap ocupa la esquina de la derecha y no se le puede poner
          // nada encima.
          const Positioned(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: IgnorePointer(child: _PastillaAmpliar()),
          ),
        ],
      ),
    );
  }
}

/// El rótulo de "esto se puede abrir". No es un botón: el objetivo táctil es la
/// franja entera que tiene detrás, y duplicar el toque aquí solo daría un blanco
/// pequeño al lado de uno grande que hace lo mismo.
class _PastillaAmpliar extends StatelessWidget {
  const _PastillaAmpliar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        boxShadow: AppElevation.flotante,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.open_in_full_rounded,
            size: 14,
            color: AppColors.primaryInk,
          ),
          const SizedBox(width: 6),
          Text(
            'Ampliar el mapa',
            style: AppText.caption.copyWith(color: AppColors.ink),
          ),
        ],
      ),
    );
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
            // El paso **actual** es el único con el color pleno; los cumplidos
            // van apagados. Iban los dos en verde y en un vistazo —que es como
            // se mira esto, conduciendo— no se sabía en cuál se está.
            color: switch (paso.indiceTracking) {
              _ when paso.indiceTracking == actual => AppColors.successInk,
              _ when paso.indiceTracking < actual => AppColors.success,
              _ => AppColors.line,
            },
          ),
          const SizedBox(width: 4),
          Text(
            paso.label,
            style: AppText.caption.copyWith(
              fontWeight: paso.indiceTracking == actual
                  ? AppText.fuerte
                  : AppText.regular,
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
          title: const Text('Ver todo el detalle', style: AppText.subtitle),
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
            // `primaryInk`: es texto, y el naranja de marca sobre blanco a este
            // tamaño da 3,1:1 — en la pantalla que se mira al sol y en
            // movimiento, es justo lo que dice de qué va el pedido.
            Expanded(
              child: Text(
                pedido.categoria.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label.copyWith(color: AppColors.primaryInk),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(pedido.descripcion, style: AppText.body),
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
                    style: AppText.caption.copyWith(color: AppColors.ink),
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
              // `Expanded` y no `Spacer`: una fila con un espaciador rígido en
              // medio no se puede recortar.
              const Expanded(
                child: Text(
                  'Comisión de la plataforma (15%)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '−${Formato.moneda(Pedido.comision(tarifa))}',
                style: AppText.caption.copyWith(
                  color: AppColors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
        if (pedido.fotoUrl != null && pedido.fotoUrl!.isNotEmpty) ...[
          const Divider(height: AppSpacing.xl),
          const Text(
            'FOTO DEL PEDIDO',
            style: AppText.label,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Mismo visor que usa la app cliente: a pantalla completa, con zoom.
          FotoAmpliable(
            url: pedido.fotoUrl!,
            titulo: 'Foto del pedido',
            alto: 140,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(fontWeight: AppText.fuerte),
              ),
              Text(
                direccion ?? 'Ubicación marcada en el mapa',
                style: AppText.body,
              ),
              if (referencia != null && referencia!.trim().isNotEmpty)
                Text(
                  'Referencia: ${referencia!}',
                  style: AppText.caption,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BotonEvidencia extends StatelessWidget {
  const _BotonEvidencia({
    required this.archivo,
    required this.onTap,
    required this.onDescartar,
    this.pesoBytes,
    this.progreso,
    this.subiendo = false,
    this.falloEnvio = false,
  });

  final File? archivo;
  final VoidCallback onTap;

  /// Descartar la foto y volver a capturar. Solo con foto y sin subida en curso.
  final VoidCallback onDescartar;

  final int? pesoBytes;

  /// Fracción 0..1 de la subida. Nula = subida en curso sin total conocido.
  final double? progreso;
  final bool subiendo;

  /// La subida falló y la foto sigue guardada. Decirlo es lo que evita que el
  /// conductor vuelva a abrir la cámara creyendo que la perdió.
  final bool falloEnvio;

  static String _peso(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).round()} KB';

  @override
  Widget build(BuildContext context) {
    final tiene = archivo != null;

    final (icono, color, titulo) = switch ((subiendo, falloEnvio, tiene)) {
      (true, _, _) => (
        Icons.cloud_upload_outlined,
        AppColors.primary,
        'Enviando la foto…',
      ),
      (_, true, _) => (
        Icons.cloud_off_outlined,
        AppColors.warning,
        'La foto sigue guardada',
      ),
      (_, _, true) => (
        Icons.check_circle,
        AppColors.success,
        'Foto lista para enviar',
      ),
      _ => (
        Icons.photo_camera_outlined,
        AppColors.inkMuted,
        'Subir foto de evidencia',
      ),
    };

    // Un spinner sin porcentaje sobre datos móviles se lee como app colgada: el
    // conductor no sabe si esperar o si volver a tocar. Con el porcentaje y el
    // peso, esperar es una decisión informada.
    final detalle = switch ((subiendo, falloEnvio, pesoBytes)) {
      (true, _, final p?) when progreso != null =>
        '${(progreso! * 100).round()}% de ${_peso(p)}',
      (true, _, final p?) => 'Enviando ${_peso(p)}…',
      (true, _, _) => null,
      (_, true, _) => 'Toca "Reintentar envío" abajo. No hace falta repetirla.',
      (_, _, final p?) => _peso(p),
      _ => 'Se comprime antes de enviarla, para que salga rápido con datos',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: falloEnvio ? AppColors.warning : AppColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            // Durante la subida no se abre la cámara: se perdería la foto que se
            // está enviando.
            onTap: subiendo ? null : onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Row(
              children: [
                Icon(icono, color: color),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (detalle != null) ...[
                        const SizedBox(height: 2),
                        Text(detalle, style: AppText.caption),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (subiendo) ...[
            const SizedBox(height: AppSpacing.md),
            // `value` nulo = indeterminado. Es lo correcto cuando Dio no informa
            // el total: mejor una barra que no promete nada que un porcentaje
            // inventado.
            LinearProgressIndicator(value: progreso),
          ],
          if (tiene && !subiendo) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onDescartar,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.inkMuted,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Tomar otra foto'),
              ),
            ),
          ],
        ],
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
                const Text('¡Pedido entregado!', style: AppText.display),
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

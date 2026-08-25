import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../data/models/polyline_codec.dart';
import '../../../data/services/location_service.dart';
import '../../../domain/models/pedido.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/encabezado.dart';
import '../../core/widgets/lugares_layer.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/primary_button.dart';
import 'pedido_activo_view_model.dart';

/// Abre el mapa del pedido a pantalla completa.
///
/// Va con el **mismo view model** de la pantalla del pedido, no con una copia de
/// sus datos: de ahí salen la posición GPS en vivo y el objetivo actual. Con una
/// copia, el mapa nacería congelado en el instante del toque y el punto azul se
/// quedaría donde el conductor estaba cuando lo abrió — que es justo lo que se
/// viene a mirar.
///
/// [onComoLlegar] se recibe de fuera en lugar de resolverse aquí porque la
/// navegación guiada tiene su propia caída (Google Maps no instalado → tienda o
/// navegador) y ya está escrita una vez en la pantalla del pedido. Duplicarla
/// sería duplicar también ese diálogo.
Future<void> abrirMapaDelPedido(
  BuildContext context,
  PedidoActivoViewModel vm, {
  required ValueChanged<LatLng> onComoLlegar,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider<PedidoActivoViewModel>.value(
        // `.value`: el dueño del view model es la pantalla del pedido. Si lo
        // creara este provider, cerrar el mapa lo desecharía y con él el reporte
        // de GPS del pedido en curso.
        value: vm,
        child: MapaPedidoScreen(onComoLlegar: onComoLlegar),
      ),
    ),
  );
}

/// El mapa del pedido, a pantalla completa.
///
/// La franja de 150 px de la pantalla del pedido es para el vistazo: dice hacia
/// dónde va el viaje mientras se trabaja. Esta pantalla es para cuando el
/// conductor **para la moto y necesita entender dónde está**: aquí caben la ruta
/// entera, los nombres de los lugares y el gesto de acercar.
class MapaPedidoScreen extends StatefulWidget {
  const MapaPedidoScreen({super.key, required this.onComoLlegar});

  final ValueChanged<LatLng> onComoLlegar;

  @override
  State<MapaPedidoScreen> createState() => _MapaPedidoScreenState();
}

class _MapaPedidoScreenState extends State<MapaPedidoScreen> {
  final _mapa = MapController();

  /// El mapa ya se pintó una vez. `MapController.camera` y `fitCamera` **lanzan**
  /// antes de eso, y aquí se llaman desde un callback de posición que puede
  /// llegar antes del primer fotograma.
  bool _listo = false;

  /// Ya se encuadró con una posición GPS real. Se hace **una sola vez**: si el
  /// mapa se abre antes del primer arreglo de GPS, el encuadre de apertura sale
  /// del viaje entero y hay que rehacerlo cuando llega la posición. Repetirlo en
  /// cada actualización sería arrancarle el mapa de las manos a quien está
  /// paneando.
  bool _encuadradoConGps = false;

  /// Márgenes del encuadre, en píxeles del mapa.
  ///
  /// No son estética: la tarjeta del objetivo flota sobre la parte de arriba y
  /// los controles sobre la de abajo. Sin descontarlas, encuadrar "me y el punto
  /// de entrega" deja el punto de entrega justo debajo del botón naranja.
  static const _margenEncuadre = EdgeInsets.fromLTRB(40, 104, 40, 184);

  void _alEstarListo() {
    _listo = true;
  }

  @override
  void dispose() {
    // `FlutterMap` solo desecha el controlador cuando lo creó él. Este es
    // nuestro, y por dentro es un `ValueNotifier` con un `StreamController` de
    // eventos: sin esto se quedan vivos cada vez que se abre el mapa.
    _mapa.dispose();
    super.dispose();
  }

  /// El tramo que se está conduciendo ahora: dónde estoy y a dónde voy.
  ///
  /// Es el encuadre por defecto y el del botón de centrar, y son el mismo a
  /// propósito: un solo modelo mental. Encuadrar el viaje entero suena más
  /// completo y es peor — en un municipio de dos kilómetros el ajuste cae por
  /// debajo de [zoomMinimoLugares] y la pantalla se abre **sin un solo lugar
  /// dibujado**, que es justo lo que se venía a ver.
  List<LatLng> _tramoActual(PedidoActivoViewModel vm) => [
        if (vm.posicion != null) vm.posicion!,
        if (vm.puntoObjetivo != null) vm.puntoObjetivo!,
      ];

  /// Todo lo que hay que poder ver del pedido. Es el respaldo mientras el GPS no
  /// ha dado la primera posición.
  List<LatLng> _todoElPedido(PedidoActivoViewModel vm, List<LatLng> ruta) => [
        ...ruta,
        if (vm.pedido?.origen != null) vm.pedido!.origen!,
        if (vm.pedido?.destino != null) vm.pedido!.destino!,
        if (vm.posicion != null) vm.posicion!,
      ];

  /// Encuadre de apertura: el tramo actual y, si aún no hay GPS, el pedido
  /// entero.
  List<LatLng> _puntosDeApertura(PedidoActivoViewModel vm, List<LatLng> ruta) {
    final tramo = _tramoActual(vm);
    return tramo.length >= 2 ? tramo : _todoElPedido(vm, ruta);
  }

  void _encuadrar(List<LatLng> puntos) {
    if (!_listo || puntos.isEmpty) return;
    if (puntos.length == 1) {
      // `CameraFit` sobre un único punto da un rectángulo de área cero y se va
      // al zoom máximo. Un punto solo no es un encuadre: es un centro.
      _mapa.move(puntos.first, 16);
      return;
    }
    _mapa.fitCamera(encuadreDePuntos(puntos, padding: _margenEncuadre));
  }

  /// Vuelve a poner en pantalla al conductor y su objetivo.
  ///
  /// Es **el único** control de cámara de la pantalla, y es deliberado: quien
  /// paneó y se perdió no quiere elegir entre "centrar en mí" y "ver todo el
  /// viaje", quiere volver a lo que estaba mirando. Este encuadre responde de una
  /// vez a "dónde estoy" y "a dónde voy", que son la misma pregunta.
  void _volverAEncuadrar(PedidoActivoViewModel vm) {
    final tramo = _tramoActual(vm);
    _encuadrar(tramo.length >= 2 ? tramo : _todoElPedido(vm, const []));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PedidoActivoViewModel>();
    final pedido = vm.pedido;
    if (pedido == null) return Scaffold(appBar: encabezado('Mapa del pedido'));

    final ruta = PolylineCodec.decode(pedido.rutaPolyline);
    final apertura = _puntosDeApertura(vm, ruta);

    // Primera posición GPS después de haber abierto el mapa sin ella.
    if (!_encuadradoConGps && vm.posicion != null && _tramoActual(vm).length >= 2) {
      _encuadradoConGps = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _volverAEncuadrar(vm);
      });
    }

    return Scaffold(
      appBar: encabezado('Mapa del pedido'),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapa,
              options: MapOptions(
                initialCenter: vm.puntoObjetivo ??
                    vm.posicion ??
                    LocationService.fallbackCenter,
                // Por encima de `zoomMinimoLugares`: abrir el mapa de los
                // lugares en un zoom donde los lugares no se dibujan es abrirlo
                // roto.
                initialZoom: 16,
                initialCameraFit: apertura.length >= 2
                    ? encuadreDePuntos(apertura, padding: _margenEncuadre)
                    : null,
                minZoom: zoomMinimoMapa,
                maxZoom: zoomMaximoMapa,
                onMapReady: _alEstarListo,
              ),
              children: [
                osmTileLayer(),
                // **Con nombres**, al revés que en la franja del pedido. Allí las
                // etiquetas taparían la ruta en 150 px; aquí son el motivo de la
                // pantalla: en un municipio sin nomenclatura, "la droguería La
                // Fe" es la dirección, y el número de la casa no existe.
                const LugaresLayer(),
                if (ruta.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: ruta,
                        strokeWidth: 5,
                        color: AppColors.primary,
                        // Filete blanco: el naranja sobre el verde de un parque o
                        // el gris de una manzana pierde el borde y la ruta se
                        // funde con el mapa.
                        borderStrokeWidth: 1.5,
                        borderColor: AppColors.surface,
                      ),
                    ],
                  ),
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
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: _TarjetaObjetivo(
              pedido: pedido,
              vaARecogida: vm.vaARecogida,
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            // `xl` y no `lg`: la atribución de OpenStreetMap ocupa los 22 px de
            // abajo a la derecha y **tiene que verse** (lo exige la licencia).
            // Con 16 px el botón se le sentaba encima en los teléfonos sin barra
            // de gestos.
            bottom: AppSpacing.xl,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BotonCentrar(onTap: () => _volverAEncuadrar(vm)),
                  const SizedBox(height: AppSpacing.md),
                  if (vm.puntoObjetivo case final LatLng objetivo)
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        // "Cómo llegar" a secas: la tarjeta de arriba ya dice a
                        // dónde. Con el destino dentro, la etiqueta se recorta
                        // con puntos suspensivos en un teléfono de 360 px, y un
                        // botón recortado es el único texto de la pantalla que no
                        // se puede permitir leer a medias.
                        label: 'Cómo llegar',
                        icon: Icons.navigation_rounded,
                        onPressed: () => widget.onComoLlegar(objetivo),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A qué punto se va ahora y con qué referencia, flotando sobre el mapa.
///
/// La referencia va aquí y no plegada en el detalle porque es **la dirección
/// real** en un municipio sin nomenclatura: "la casa del portón verde" ubica y
/// "Cra. 8a # 17-8" no, cuando ninguna esquina tiene placa.
class _TarjetaObjetivo extends StatelessWidget {
  const _TarjetaObjetivo({required this.pedido, required this.vaARecogida});

  final Pedido pedido;
  final bool vaARecogida;

  @override
  Widget build(BuildContext context) {
    final direccion =
        vaARecogida ? pedido.direccionRecogida : pedido.direccionDestino;
    final referencia =
        vaARecogida ? pedido.referenciaRecogida : pedido.referencia;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.line),
        boxShadow: AppElevation.flotante,
      ),
      child: Row(
        children: [
          Icon(
            vaARecogida ? Icons.storefront : Icons.location_on,
            // Los mismos dos colores que los pines del mapa: la tarjeta dice
            // cuál de los dos pines es el de ahora sin tener que leerla.
            color: vaARecogida ? AppColors.accent : AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vaARecogida ? 'VAS A RECOGER EN' : 'VAS A ENTREGAR EN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label,
                ),
                Text(
                  direccion ?? 'Ubicación marcada en el mapa',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subtitle,
                ),
                if (referencia != null && referencia.trim().isNotEmpty)
                  Text(
                    referencia,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vuelve a encuadrar el mapa en el conductor y su objetivo.
class _BotonCentrar extends StatelessWidget {
  const _BotonCentrar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // `container: true`: sin él el nodo se funde con lo que hay alrededor y un
      // icono de diana no se anuncia como nada.
      container: true,
      button: true,
      label: 'Volver a centrar el mapa en ti y en tu destino',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppElevation.flotante,
        ),
        child: Material(
          color: AppColors.surface,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Tooltip(
              message: 'Volver a centrar el mapa',
              // El lector de pantalla ya recibe la etiqueta larga de arriba; sin
              // esto anunciaría las dos, una detrás de otra.
              excludeFromSemantics: true,
              child: const SizedBox(
                // El mínimo táctil entero: es un botón que se toca con guante y
                // con la moto al ralentí.
                width: AppSpacing.minTouchTarget,
                height: AppSpacing.minTouchTarget,
                child: Icon(
                  Icons.my_location_rounded,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

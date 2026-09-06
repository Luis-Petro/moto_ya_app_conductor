import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/models/demanda_zonas.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/lugares_layer.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/skeleton.dart';

/// Alto del área del mapa de zonas, **fijo**, derivado del ancho de la pantalla.
///
/// Antes eran dos altos: todo lo que sobrara de pantalla si no había avisos, y
/// 260 px si los había. Eso hacía que la llegada de un banner —una oferta, un
/// aviso de batería, un pedido nuevo— reorganizara la pantalla entera con el
/// encuadre y el zoom moviéndose debajo del dedo del conductor mientras miraba.
/// El bloque de demanda es una tarjeta más del Inicio: la pantalla se desplaza,
/// no se reorganiza.
///
/// Se deriva del ancho y no es un número absoluto por lo mismo que la franja de
/// avisos fija su proporción: 260 px son media pantalla en un teléfono pequeño y
/// una cuarta parte en uno grande. La proporción algo más alta que ancha es la
/// de la referencia de diseño, y es la que deja ver el casco urbano con su
/// periferia a la vez.
///
/// El tope sobre el alto de pantalla es para el teléfono ancho y corto —o el
/// modo horizontal—, donde `ancho × 1,1` se comería el bloque de ganancias.
double altoDelMapaDeZonas(BuildContext context) {
  final pantalla = MediaQuery.sizeOf(context);
  // El ancho disponible descuenta el padding lateral del sliver.
  final ancho = pantalla.width - AppSpacing.lg * 2;
  return (ancho * 1.1).clamp(200.0, pantalla.height * 0.55);
}

/// Cuánto se deja la cámara en manos del conductor tras un gesto suyo.
///
/// Soltarla del todo era lo correcto para no pelearse con quien mira otra
/// esquina, y dejaba al conductor con el mapa parado en un rincón el resto de la
/// sesión. Soltarla un rato es lo mismo que hace el seguimiento del cliente, y
/// por el mismo motivo.
const Duration esperaTrasElGesto = Duration(seconds: 10);

/// Dónde han salido pedidos, con datos del backend.
///
/// Antes esto dibujaba tres círculos alrededor del conductor con offsets fijos:
/// parecía información y no lo era. Nunca se pinta un mapa inventado sobre el
/// que alguien podría decidir dónde pararse a esperar.
///
/// El backend ensancha la ventana si en las últimas horas no hubo pedidos (en un
/// municipio de 5 pedidos al día casi nunca los hay) y devuelve cuál usó: el
/// encabezado pinta ese periodo.
///
/// **Recibe los cinco datos que usa, no el view model del Inicio.** Con el view
/// model entero este bloque solo se podía probar leyendo su código fuente, y las
/// tres cosas que aquí no pueden romperse —el alto que no cambia, el encuadre
/// que se rehace y el orden de las capas— son exactamente las que al romperse no
/// dan ningún error: compilan, no se ven en un diff y solo se notan mirando el
/// mapa con demanda y lugares solapados.
class MapaDeZonas extends StatefulWidget {
  const MapaDeZonas({
    super.key,
    required this.demanda,
    required this.cargando,
    required this.ubicacion,
    required this.centroMunicipio,
    required this.onReintentar,
  });

  /// Lo que devolvió el backend. `null` = no se pudo traer (o sigue en vuelo,
  /// que lo dice [cargando]).
  final DemandaZonas? demanda;
  final bool cargando;

  /// Dónde está el conductor, si el GPS ya contestó.
  final LatLng? ubicacion;

  /// Centro del municipio: el respaldo del encuadre cuando no hay ni celdas ni
  /// ubicación. Nulo es un caso normal — un municipio puede no declararlo.
  final LatLng? centroMunicipio;

  final VoidCallback onReintentar;

  @override
  State<MapaDeZonas> createState() => _MapaDeZonasState();
}

class _MapaDeZonasState extends State<MapaDeZonas> {
  /// Hace falta para reencuadrar **después** del primer fotograma:
  /// `initialCameraFit` solo se lee al montar el mapa, y la demanda es la
  /// consulta más lenta del Inicio — casi siempre llega después.
  final _mapa = MapController();

  /// Si la cámara sigue a los datos. El gesto del conductor la suelta.
  bool _siguiendo = true;
  Timer? _reanudar;

  /// Lo último que se encuadró, para no reencuadrar en cada `build`.
  List<LatLng> _encuadrado = const [];

  @override
  void didUpdateWidget(covariant MapaDeZonas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reencuadrarSiCambio();
  }

  @override
  void dispose() {
    // Un `Timer` pendiente sobrevive al desmontaje y hace fallar cualquier
    // `testWidgets` que lo dispare.
    _reanudar?.cancel();
    _mapa.dispose();
    super.dispose();
  }

  /// Los puntos que el mapa tiene que contener. Sin celdas ni ubicación cae al
  /// centro del municipio, y sin él al punto de respaldo de la app: un mapa sin
  /// encuadre no es una opción.
  List<LatLng> get _puntos {
    final d = widget.demanda;
    final puntos = <LatLng>[
      if (d != null)
        for (final c in d.celdas) c.centro,
      if (widget.ubicacion != null) widget.ubicacion!,
    ];
    if (puntos.isNotEmpty) return puntos;
    final centro = widget.centroMunicipio;
    return centro == null ? const [] : [centro];
  }

  void _reencuadrarSiCambio() {
    if (!_siguiendo) return;
    final puntos = _puntos;
    if (_mismosPuntos(puntos, _encuadrado)) return;
    _encuadrado = puntos;
    // Tras el fotograma: durante `didUpdateWidget` el mapa puede no tener aún
    // tamaño, y `fitCamera` sobre un mapa sin medir no encuadra nada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapa.fitCamera(encuadreDePuntos(puntos));
    });
  }

  static bool _mismosPuntos(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// El conductor movió el mapa: se le deja mirar sin pelearse con él, pero solo
  /// un rato — al volver, su posición y las zonas vuelven a estar en pantalla.
  void _soltarCamara() {
    _reanudar?.cancel();
    _reanudar = Timer(esperaTrasElGesto, () {
      if (mounted) _retomarCamara();
    });
    if (_siguiendo) setState(() => _siguiendo = false);
  }

  void _retomarCamara() {
    _reanudar?.cancel();
    if (mounted) setState(() => _siguiendo = true);
    _encuadrado = const [];
    _reencuadrarSiCambio();
  }

  /// El área del mapa.
  ///
  /// Antes esto era una variable calculada al principio del `build`, así que se
  /// construía **siempre que `demanda != null`** — incluso cuando la rama de
  /// "todavía no hay pedidos" la descartaba. Y ese es justo el caso en que
  /// `LatLngBounds.fromPoints` recibía la lista vacía y lanzaba. Que sea un
  /// método y se llame solo desde su rama es lo que lo hace imposible;
  /// [encuadreDePuntos] es el cinturón.
  Widget _mapaDeZonas(DemandaZonas d) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapa,
              options: MapOptions(
                // Sigue haciendo falta: es lo que dibuja el primer fotograma,
                // antes de que haya nada que reencuadrar.
                initialCameraFit: encuadreDePuntos(_puntos),
                minZoom: zoomMinimoMapa,
                maxZoom: zoomMaximoMapa,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
                // `hasGesture` es la única señal fiable de "lo movió él":
                // deducirlo de la posición resultante es una carrera contra el
                // propio `fitCamera`, y se pierde.
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture) _soltarCamara();
                },
              ),
              children: capasDelMapaDeZonas(
                celdas: d.celdas,
                ubicacion: widget.ubicacion,
              ),
            ),
          ),
          // La leyenda va encima del mapa, no debajo: como fila aparte se
          // llevaba una línea entera de la pantalla y era justo la que
          // quedaba cortada.
          const Positioned(
            left: AppSpacing.sm,
            top: AppSpacing.sm,
            child: _Leyenda(),
          ),
          if (!_siguiendo)
            Positioned(
              right: AppSpacing.sm,
              top: AppSpacing.sm,
              child: BotonRecentrar(onTap: _retomarCamara),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.demanda;
    // Los tres estados miden lo mismo: si el esqueleto y el aviso midieran
    // menos, la pantalla daría un salto justo al llegar los datos.
    final alto = altoDelMapaDeZonas(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Dónde están pidiendo',
              style: AppText.subtitle.copyWith(fontWeight: AppText.fuerte),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                // Solo el periodo, **nunca cuántos pedidos hubo**. El total es
                // la cifra de negocio del municipio, y enseñársela a cada
                // conductor la convierte en una medida de lo que la plataforma
                // mueve —"once pedidos en todo el día"— justo en la pantalla
                // desde la que decide si vale la pena salir. Dónde pararse lo
                // dicen los círculos, no ese número.
                //
                // El periodo sí se queda: sin él las manchas no significan nada
                // —no es lo mismo que sean de las últimas dos horas que del
                // último mes—, y la ventana la decide el servidor y cambia sola.
                d != null && d.tieneDatos ? d.periodoLabel : 'Últimas horas',
                style: AppText.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.cargando)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // La consulta de demanda es la más lenta del Inicio: el backend ensancha
        // la ventana (2 h → 24 h → 7 d → 30 d → 1 año → todo) hasta juntar cinco
        // pedidos. Sin esta rama, `demanda == null` con la consulta en vuelo no
        // caía en ninguna de las tres de abajo y dejaba medio alto de pantalla en
        // blanco — que es la mitad del reporte de "el home queda en blanco".
        // Va condicionada a `d == null` a propósito: al refrescar con datos ya en
        // pantalla, cambiar el mapa por un esqueleto sería un paso atrás (para eso
        // está el indicador pequeño del encabezado).
        SizedBox(
          height: alto,
          child: switch (d) {
            null when widget.cargando => const Skeleton(
              height: double.infinity,
              radius: AppSpacing.radiusMd,
            ),
            null => _AvisoDemanda(
              icono: Icons.cloud_off_outlined,
              texto: 'No pudimos cargar las zonas de demanda.',
              accion: widget.onReintentar,
            ),
            final z when !z.tieneDatos => const _AvisoDemanda(
              icono: Icons.query_stats_outlined,
              texto:
                  'Todavía no hay ningún pedido registrado en tu zona. En cuanto '
                  'entre el primero, aparece en el mapa.',
            ),
            final z => _mapaDeZonas(z),
          },
        ),
      ],
    );
  }
}

/// Las capas del mapa de zonas, **en su orden**.
///
/// Es una función aparte porque el orden es contrato y hay que poder contarlo en
/// un test: los círculos de demanda son manchas translúcidas de varios cientos
/// de metros de radio, y dibujadas encima tapaban el nombre de la droguería
/// justo en las zonas con pedidos — las únicas que hay que mirar. Una mancha
/// sobre calles sin nombre no le sirve a nadie para decidir dónde pararse.
///
/// De abajo arriba: mapa base → demanda → lugares → dónde estoy yo. Lo último es
/// lo único que contesta "¿dónde estoy respecto a esto?", así que no lo tapa
/// nada.
List<Widget> capasDelMapaDeZonas({
  required List<CeldaDemanda> celdas,
  required LatLng? ubicacion,
}) {
  return [
    osmTileLayer(),
    CircleLayer(
      circles: [
        for (final c in celdas)
          CircleMarker(
            point: c.centro,
            // ~media celda de la rejilla del backend (0.005°).
            radius: 280,
            useRadiusInMeter: true,
            color: colorDeNivel(c.nivel).withValues(alpha: 0.18),
            borderColor: colorDeNivel(c.nivel).withValues(alpha: 0.35),
            borderStrokeWidth: 1,
          ),
      ],
    ),
    // Recarga al reaparecer: este mapa vive en el shell y no se desmonta nunca,
    // así que su `initState` es el único intento de toda la sesión y cae siempre
    // en el arranque en frío.
    const LugaresLayer(recargarAlReaparecer: true),
    if (ubicacion != null) MarkerLayer(markers: [usuarioMarker(ubicacion)]),
    osmAttribution(),
  ];
}

/// El color de cada nivel de demanda. Lo usan el mapa y la leyenda.
Color colorDeNivel(NivelDemanda n) => switch (n) {
  NivelDemanda.alta => AppColors.danger,
  NivelDemanda.media => AppColors.warning,
  NivelDemanda.baja => AppColors.success,
};

/// Vuelve a encuadrar las zonas y la posición del conductor.
///
/// Solo aparece con la cámara suelta: un botón permanente en un mapa que ya está
/// centrado es un control que no hace nada.
class BotonRecentrar extends StatelessWidget {
  const BotonRecentrar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            Icons.my_location,
            size: 20,
            color: AppColors.ink,
            semanticLabel: 'Volver a centrar el mapa',
          ),
        ),
      ),
    );
  }
}

/// Leyenda de niveles, en una pastilla sobre el mapa.
class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.line),
        // Flota sobre el mapa: tiene que leerse igual sobre una calle blanca
        // que sobre una zona verde, y el borde solo no lo consigue.
        boxShadow: AppElevation.flotante,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final n in NivelDemanda.values) ...[
            if (n != NivelDemanda.values.first)
              const SizedBox(width: AppSpacing.sm),
            _PuntoLeyenda(color: colorDeNivel(n), label: n.label),
          ],
        ],
      ),
    );
  }
}

class _PuntoLeyenda extends StatelessWidget {
  const _PuntoLeyenda({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.35),
            border: Border.all(color: color),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppText.caption),
      ],
    );
  }
}

class _AvisoDemanda extends StatelessWidget {
  const _AvisoDemanda({required this.icono, required this.texto, this.accion});
  final IconData icono;
  final String texto;
  final VoidCallback? accion;

  @override
  Widget build(BuildContext context) {
    return MotoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(texto, style: AppText.body),
          ),
          if (accion != null)
            TextButton(onPressed: accion, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

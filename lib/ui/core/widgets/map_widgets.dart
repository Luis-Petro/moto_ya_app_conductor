import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:latlong2/latlong.dart';

import '../../../config/env.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/map_tile_cache.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Zoom mínimo de cualquier mapa de la app.
///
/// Más lejos que esto el municipio entero cabe en una uña y el mapa deja de
/// servir para ubicar nada.
const double zoomMinimoMapa = 11;

/// Zoom máximo de cualquier mapa de la app: el último nivel con tiles reales.
/// Pasado este punto el mapa se quedaba en gris.
const double zoomMaximoMapa = 19;

/// Encuadre inicial que abarca [puntos], **con la lista vacía resuelta**.
///
/// `LatLngBounds.fromPoints` lanza si la lista viene vacía. Eso ocurrió de verdad
/// en el mapa de demanda del Inicio (celdas vacías y ubicación aún sin resolver)
/// y en release se vio como un **rectángulo gris mudo**: el `ErrorWidget` por
/// defecto no escribe nada, así que el reporte llegó como "el home se queda en
/// blanco" en vez de como una excepción.
///
/// Un mapa centrado en el municipio es un desenlace honesto; una excepción en
/// medio del `build` no lo es.
CameraFit encuadreDePuntos(
  List<LatLng> puntos, {
  EdgeInsets padding = const EdgeInsets.all(28),
  LatLng respaldo = LocationService.fallbackCenter,
  double zoomRespaldo = 14,
}) {
  if (puntos.isEmpty) {
    return CameraFit.coordinates(
      coordinates: [respaldo],
      maxZoom: zoomRespaldo,
    );
  }
  return CameraFit.bounds(
    bounds: LatLngBounds.fromPoints(puntos),
    padding: padding,
  );
}

/// Capa de tiles configurable (ADR-008).
///
/// Los datos son de OpenStreetMap; quien los dibuja y los sirve lo decide
/// [Env.tileUrl] (Geoapify en producción).
///
/// Usa caché en disco ([MapTileCache]) cuando está disponible: cada tile visto
/// se guarda y se reutiliza. Aquí importa más que en la app cliente —el mapa
/// está abierto todo el domicilio y el municipio es siempre el mismo—, y con
/// proveedor de cuota diaria cada tile reutilizado es un crédito que no se
/// gasta. Si la caché no se inicializó, cae al proveedor de red estándar.
TileLayer osmTileLayer() {
  final store = MapTileCache.store;
  return TileLayer(
    urlTemplate: Env.tileUrl,
    userAgentPackageName: 'com.zumbeo.conductor',
    // `maxNativeZoom`, no `maxZoom`: con `maxZoom` la capa deja de pintarse por
    // encima del valor y el mapa queda gris con los marcadores flotando.
    // `maxNativeZoom` es hasta dónde se piden tiles; más allá reescala el
    // último nivel, así que siempre se ve algo.
    maxNativeZoom: 19,
    // Solo los tiles visibles. El default (`panBuffer: 1`) carga un anillo extra
    // alrededor de la pantalla: pasa de ~15 tiles por apertura a ~35, y el plan
    // del proveedor limita las peticiones por segundo, así que ese anillo se
    // traduce en cuadros grises justo al abrir el mapa. El precio es ver tiles
    // cargando al panear, y solo la primera vez en cada zona: lo demás sale de
    // la caché de disco.
    panBuffer: 0,
    tileProvider: store != null
        ? CachedTileProvider(store: store, maxStale: const Duration(days: 30))
        : NetworkTileProvider(),
  );
}

/// Una ilustración de marca usada como marcador del mapa.
///
/// Son **los mismos tres dibujos que la app cliente** (tienda, casa y la moto de
/// la mascota). Conductor y cliente miran el mismo pedido, y cuando hablan por
/// teléfono ("estoy en el pin de la casa") tienen que estar viendo lo mismo.
///
/// El tamaño es contrato: la imagen se empaqueta a 3× su tamaño lógico y ni un
/// píxel más, y `test/assets/marcadores_mapa_test.dart` lo comprueba leyendo
/// estas mismas constantes.
class IlustracionMarcador {
  const IlustracionMarcador({
    required this.asset,
    required this.alto,
    required this.aspecto,
    required this.iconoRespaldo,
    required this.colorRespaldo,
  });

  /// Ruta del asset empaquetado.
  final String asset;

  /// Alto en puntos lógicos con el que se pinta.
  final double alto;

  /// Ancho dividido por alto de la imagen ya recortada a su contenido.
  final double aspecto;

  /// Qué se pinta si el asset no carga. Un pedido sin marcador de entrega es
  /// peor que uno con un icono genérico, así que el respaldo no es opcional.
  final IconData iconoRespaldo;
  final Color colorRespaldo;

  double get ancho => alto * aspecto;
}

/// Pin de la tienda: dónde se recoge o se compra.
const marcadorRecogida = IlustracionMarcador(
  asset: 'assets/images/marcador_recogida.png',
  alto: 44,
  aspecto: 89 / 132,
  iconoRespaldo: Icons.storefront_rounded,
  colorRespaldo: AppColors.accent,
);

/// Pin de la casa: dónde se entrega.
const marcadorEntrega = IlustracionMarcador(
  asset: 'assets/images/marcador_entrega.png',
  alto: 44,
  aspecto: 91 / 132,
  iconoRespaldo: Icons.location_pin,
  colorRespaldo: AppColors.primaryDark,
);

/// La moto de la mascota: el propio conductor.
///
/// Sustituye al punto naranja de antes. Un punto del mismo naranja que la ruta
/// y que el pin de entrega no decía "este eres tú": se confundía con un vértice
/// de la línea.
const marcadorConductor = IlustracionMarcador(
  asset: 'assets/images/marcador_conductor.png',
  alto: 56,
  aspecto: 142 / 168,
  iconoRespaldo: Icons.two_wheeler_rounded,
  colorRespaldo: AppColors.primary,
);

/// La imagen de un marcador ilustrado, suelta, para usarla **fuera del mapa**.
///
/// La tarjeta del paso actual y el resumen del recorrido pintan el mismo pin que
/// el mapa: así "la tienda azul" y "la casa naranja" significan lo mismo en toda
/// la pantalla, sin tener que leer nada.
class ImagenMarcador extends StatelessWidget {
  const ImagenMarcador(this.ilustracion, {super.key, this.alto});

  final IlustracionMarcador ilustracion;

  /// Alto con el que se pinta; por defecto, el del mapa.
  final double? alto;

  @override
  Widget build(BuildContext context) {
    final h = alto ?? ilustracion.alto;
    final w = h * ilustracion.aspecto;
    final densidad = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3;
    return Image.asset(
      ilustracion.asset,
      width: w,
      height: h,
      cacheWidth: (w * densidad).round(),
      cacheHeight: (h * densidad).round(),
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => Icon(
        ilustracion.iconoRespaldo,
        color: ilustracion.colorRespaldo,
        size: h * 0.8,
      ),
    );
  }
}

/// Ancho del marcador cuando lleva rótulo encima: cabe "Recoge aquí" en la
/// tipografía del rótulo sin cortarse.
const double _anchoConRotulo = 112;

/// Alto del rótulo que va sobre el pin, separación incluida.
const double _altoRotulo = 26;

/// Marcador con ilustración de marca, anclado por su borde inferior.
///
/// **`Alignment.topCenter` es lo que ancla la punta al punto**, por contradictorio
/// que suene: `MarkerLayer` coloca el widget en `top = y - alto` cuando la
/// alineación es `topCenter`, así que el borde **inferior** de la ilustración
/// cae sobre la coordenada. Con la alineación por defecto (`center`) un pin de
/// 44 dp señalaría 22 dp más arriba del sitio — media cuadra a zoom 16.
///
/// [rotulo] pinta una pastilla encima del pin ("Recoge aquí", "Tú"). Es para
/// quien no lee mapas: un dibujo de una tienda sobre un plano no dice "ve aquí",
/// una palabra sí. Como la pastilla va **encima** del pin, el borde inferior
/// sigue siendo la punta y el anclaje no cambia.
///
/// [rumbo] (0 = norte, 90 = este) voltea la ilustración cuando el avance va
/// hacia el oeste: la mascota está dibujada mirando a la derecha, y una moto que
/// va hacia el oeste dibujada mirando al este se lee como que va marcha atrás.
///
/// [opacidad] apaga el punto que **no** es el objetivo actual: los dos pines
/// siguen en el mapa, pero solo uno grita.
Marker marcadorIlustrado(
  LatLng punto,
  IlustracionMarcador ilustracion, {
  required String semantica,
  String? rotulo,
  Color colorRotulo = AppColors.accent,
  double densidad = 3,
  double? rumbo,
  double opacidad = 1,
}) {
  // Decodificar ya al tamaño de destino: sin esto el bitmap se guarda grande y
  // se reescala en cada pintada.
  final anchoPx = (ilustracion.ancho * densidad).round();
  final altoPx = (ilustracion.alto * densidad).round();

  Widget imagen = Image.asset(
    ilustracion.asset,
    width: ilustracion.ancho,
    height: ilustracion.alto,
    cacheWidth: anchoPx,
    cacheHeight: altoPx,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, __, ___) => Icon(
      ilustracion.iconoRespaldo,
      color: ilustracion.colorRespaldo,
      size: ilustracion.alto * 0.8,
    ),
  );
  if (rumbo != null && rumbo > 180) {
    imagen = Transform.flip(flipX: true, child: imagen);
  }

  Widget contenido = imagen;
  if (rotulo != null) {
    contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: _altoRotulo - 4,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorRotulo,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            rotulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppText.familia,
              fontSize: 12,
              fontWeight: AppText.fuerte,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        imagen,
      ],
    );
  }
  if (opacidad < 1) {
    contenido = Opacity(opacity: opacidad, child: contenido);
  }

  return Marker(
    point: punto,
    width: rotulo != null ? _anchoConRotulo : ilustracion.ancho,
    height: ilustracion.alto + (rotulo != null ? _altoRotulo : 0),
    alignment: Alignment.topCenter,
    child: Semantics(
      container: true,
      label: semantica,
      image: true,
      child: contenido,
    ),
  );
}

/// Marcador circular del propio usuario.
Marker usuarioMarker(LatLng punto) {
  return Marker(
    point: punto,
    width: 22,
    height: 22,
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    ),
  );
}

/// Atribución del mapa (requerida por licencia, no es decorativa).
///
/// La ODbL exige el crédito a *contributors*, no solo al proyecto. Cuando los
/// tiles los sirve Geoapify hay que acreditarlo también —lo piden sus términos
/// de uso gratuito—, y solo entonces: con tiles propios en R2 no hay tercero a
/// quien nombrar.
///
/// Va sobre una placa blanca translúcida porque un texto gris de 9 px sin fondo
/// se pierde según el tile que le toque debajo, y esto es justo lo que no puede
/// quedar ilegible.
Widget osmAttribution() {
  return Align(
    alignment: Alignment.bottomRight,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Text(
            Env.tilesGeoapify || Env.ruteoGeoapify
                ? '© OpenStreetMap contributors · Powered by Geoapify'
                : '© OpenStreetMap contributors',
            // A Geoapify se le acredita cuando sirve los tiles o cuando calculó
            // las rutas que se dibujan: sus términos gratuitos lo exigen igual, y
            // el ruteo lo decide el backend, no esta app.
            // Más pequeño que `caption` a propósito: es la atribución exigida
            // por la licencia, tiene que estar y tiene que poder leerse, pero no
            // compite con nada de lo que hay sobre el mapa.
            style: AppText.caption.copyWith(fontSize: 9),
          ),
        ),
      ),
    ),
  );
}

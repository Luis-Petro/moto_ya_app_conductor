import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../data/repositories/usuario_repository.dart';
import '../../../data/services/lugar_service.dart';
import '../../../di/locator.dart';
import '../../../domain/models/lugar.dart';
import 'lugar_marcadores.dart';

/// Capa del catálogo de lugares para cualquier `FlutterMap`.
///
/// Va como hijo del mapa, entre los tiles y los marcadores del pedido:
///
/// ```dart
/// children: [
///   osmTileLayer(),
///   const LugaresLayer(),
///   MarkerLayer(markers: [...]),  // recogida, entrega, mi posición
/// ]
/// ```
///
/// Lee el zoom de la cámara del mapa que la contiene (`MapCamera.of`), así que
/// se repinta sola al acercar y la pantalla no tiene que seguir la cámara.
///
/// **Para el conductor esto no es decoración, es la nomenclatura del pueblo.**
/// Las calles del municipio no tienen nombre ni número en el mapa; lo que le
/// dice dónde está es la plaza, la droguería y el D1. Y el catálogo lo alimenta
/// él mismo: cada lugar que propone se lo encuentra dibujado la próxima vez.
///
/// Los lugares que son un **área** (el parque, el polideportivo, la cancha) se
/// dibujan además como polígono debajo de los marcadores. "Te espero en el
/// parque" deja de ser un pin flotando en medio de la nada.
class LugaresLayer extends StatefulWidget {
  const LugaresLayer({
    super.key,
    this.municipioId,
    this.onTap,
    this.mostrarNombres = true,
  });

  /// Municipio del catálogo. Si es `null` se toma el del usuario en caché.
  final int? municipioId;

  /// Qué hacer al tocar un lugar. En los mapas de solo lectura no se pasa: los
  /// lugares son referencia visual y tocarlos no debe hacer nada.
  final ValueChanged<Lugar>? onTap;

  /// Si se permite la etiqueta con el nombre al acercar. Se apaga en los mapas
  /// pequeños del pedido (150–220 px): ahí las etiquetas tapan la ruta, que es
  /// justo lo que esa pantalla va a mostrar.
  final bool mostrarNombres;

  @override
  State<LugaresLayer> createState() => _LugaresLayerState();
}

class _LugaresLayerState extends State<LugaresLayer> {
  List<Lugar> _lugares = const [];

  /// Esperas entre reintentos, escalonadas.
  ///
  /// Antes era **un solo reintento a los 2 segundos**, y eso no es un arreglo:
  /// es una moneda al aire. Si el perfil del usuario tardaba 2,5 segundos —una
  /// red de municipio, un arranque en frío, un teléfono lento—, la capa se
  /// rendía para siempre y el mapa salía sin un solo marcador, sin error y sin
  /// nada que reintentar. En el Inicio del conductor el perfil se pide con
  /// `unawaited`, así que esa carrera se pierde a diario: es el "a veces carga
  /// y a veces no".
  ///
  /// Escalonado y acotado: mira durante unos quince segundos y para. Si en ese
  /// tiempo no llegó, insistir no va a traerlo.
  static const _esperas = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 4),
    Duration(seconds: 5),
  ];

  /// Cada cuánto se vuelve a mirar si el municipio **ya llegó**.
  ///
  /// Esperar al municipio no es reintentar una consulta que falló: no hay red
  /// de por medio, es leer una caché en memoria. Gastaba pasos de la escalera
  /// de arriba, y ahí estaba el "a veces se ven los sitios y a veces no": si el
  /// perfil del usuario tardaba más de los quince segundos de la escalera —red
  /// de municipio, arranque en frío, teléfono de gama media—, la capa se rendía
  /// **sin haber preguntado ni una vez** al servidor, y el mapa se quedaba sin
  /// un solo marcador hasta reiniciar la app.
  static const _esperaMunicipio = Duration(seconds: 1);

  /// Cuántas veces se mira antes de rendirse. Treinta segundos: más allá de
  /// eso, el perfil no va a llegar solo.
  static const _miradasAlMunicipio = 30;

  int _intento = 0;
  Timer? _reintento;

  /// Cuántas veces se ha mirado si ya hay municipio, sin encontrarlo.
  int _esperasDeMunicipio = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant LugaresLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.municipioId != oldWidget.municipioId) {
      _intento = 0;
      _esperasDeMunicipio = 0;
      _cargar();
    }
  }

  @override
  void dispose() {
    _reintento?.cancel();
    super.dispose();
  }

  /// Programa otro intento, si quedan. Con un `Timer` cancelable y no con un
  /// `await` suelto: al salir de la pantalla, el `await` seguía vivo y volvía
  /// sobre un `State` ya desmontado.
  void _reintentar() {
    if (_intento >= _esperas.length) return;
    final espera = _esperas[_intento];
    _intento++;
    _reintento?.cancel();
    _reintento = Timer(espera, () {
      if (mounted) _cargar();
    });
  }

  /// Vuelve a mirar dentro de un segundo si ya hay municipio. Contador propio,
  /// separado de la escalera de reintentos: esperar un dato que aún no llegó y
  /// reintentar una consulta que falló son dos cosas distintas.
  void _esperarMunicipio() {
    if (_esperasDeMunicipio >= _miradasAlMunicipio) return;
    _esperasDeMunicipio++;
    _reintento?.cancel();
    _reintento = Timer(_esperaMunicipio, () {
      if (mounted) _cargar();
    });
  }

  Future<void> _cargar() async {
    final municipioId =
        widget.municipioId ?? locator<UsuarioRepository>().enCache?.municipioId;
    if (municipioId == null) {
      // El municipio todavía no ha llegado. Volver a mirar es lo que evita el
      // caso mudo: montarse antes que el municipio y no enterarse nunca de que
      // ya está, porque `didUpdateWidget` solo se dispara si el valor que llega
      // por parámetro cambia — y en las pantallas que lo toman de la caché del
      // usuario ese parámetro es null siempre.
      _esperarMunicipio();
      return;
    }
    _esperasDeMunicipio = 0;
    final lugares = await locator<LugarService>().catalogoDeMapa(municipioId);
    if (!mounted) return;
    if (lugares == null) {
      // Falló la consulta. Se reintenta con la misma escalera; el motivo ya
      // quedó en el log del servicio y el mapa sin marcadores sigue sirviendo.
      _reintentar();
      return;
    }
    if (lugares.isEmpty) return;
    _reintento?.cancel();
    setState(() => _lugares = lugares);
  }

  @override
  Widget build(BuildContext context) {
    if (_lugares.isEmpty) return const SizedBox.shrink();
    final zoom = MapCamera.of(context).zoom;
    if (zoom < zoomMinimoLugares) return const SizedBox.shrink();
    final marcadores = MarkerLayer(
      markers: marcadoresDeLugares(
        _lugares,
        zoom: zoom,
        onTap: widget.onTap,
        permitirNombres: widget.mostrarNombres,
      ),
    );
    final poligonos = poligonosDeLugares(_lugares);
    if (poligonos.isEmpty) return marcadores;
    // Las áreas van debajo de los marcadores, para que ningún relleno tape un
    // pin. `Positioned.fill` da a las dos capas el mismo tamaño que tendrían
    // como hijas directas del mapa.
    return Positioned.fill(
      child: Stack(children: [PolygonLayer(polygons: poligonos), marcadores]),
    );
  }
}

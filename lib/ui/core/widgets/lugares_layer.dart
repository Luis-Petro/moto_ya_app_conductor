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

  /// Reintentos gastados. Uno basta: si el catálogo no llega a la segunda, no va
  /// a llegar por insistir dentro de la misma pantalla.
  int _reintentos = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant LugaresLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.municipioId != oldWidget.municipioId) {
      _reintentos = 0;
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final municipioId =
        widget.municipioId ?? locator<UsuarioRepository>().enCache?.municipioId;
    if (municipioId == null) {
      // El municipio todavía no ha llegado. Volver a mirar en un momento es lo
      // que evita el caso mudo: montarse antes que el municipio y no enterarse
      // nunca de que ya está, porque `didUpdateWidget` solo se dispara si el
      // valor que llega por parámetro cambia — y en las pantallas que lo toman
      // de la caché del usuario ese parámetro es null siempre. En el Inicio del
      // conductor el perfil se pide con `unawaited`, así que esa carrera se
      // pierde a diario: es el "a veces carga y a veces no".
      if (_reintentos == 0) {
        _reintentos++;
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) await _cargar();
      }
      return;
    }
    final lugares = await locator<LugarService>().catalogoDeMapa(municipioId);
    if (!mounted) return;
    if (lugares == null) {
      // Falló. Un reintento y se deja estar: el mapa sin marcadores sigue
      // sirviendo, y el motivo ya quedó en el log del servicio.
      if (_reintentos < 2) {
        _reintentos++;
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) await _cargar();
      }
      return;
    }
    if (lugares.isEmpty) return;
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

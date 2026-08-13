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

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant LugaresLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.municipioId != oldWidget.municipioId) _cargar();
  }

  Future<void> _cargar() async {
    final municipioId =
        widget.municipioId ?? locator<UsuarioRepository>().enCache?.municipioId;
    if (municipioId == null) return;
    final lugares = await locator<LugarService>().catalogoDeMapa(municipioId);
    if (!mounted || lugares.isEmpty) return;
    setState(() => _lugares = lugares);
  }

  @override
  Widget build(BuildContext context) {
    if (_lugares.isEmpty) return const SizedBox.shrink();
    final zoom = MapCamera.of(context).zoom;
    if (zoom < zoomMinimoLugares) return const SizedBox.shrink();
    return MarkerLayer(
      markers: marcadoresDeLugares(
        _lugares,
        zoom: zoom,
        onTap: widget.onTap,
        permitirNombres: widget.mostrarNombres,
      ),
    );
  }
}

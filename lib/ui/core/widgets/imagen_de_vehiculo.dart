import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/services/banner_image_store.dart';
import '../../../di/locator.dart';
import '../../../domain/models/catalogo_vehiculos.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// La imagen de una fila del catálogo de vehículos, con **silueta de respaldo**.
///
/// Reutiliza [BannerImageStore] —el mismo `dio_cache_interceptor` que ya cachea
/// los tiles del mapa y las imágenes de los avisos, 30 días en disco— en vez de
/// añadir un paquete de imágenes en red. Al abrir el paso del vehículo se piden
/// las imágenes de las marcas del tipo elegido, y sin caché eso se bajaría en
/// cada intento de registro.
///
/// **La condición para pintar es «hay bytes», no «el código es 200»**: una
/// respuesta servida desde la caché llega con **304**, y con
/// `CachePolicy.forceCache` ese es el camino normal a partir de la segunda vez.
/// Exigir un 200 dejaría cada imagen visible una sola vez y luego invisible los
/// 30 días de `maxStale` — es el fallo que ya costó los avisos de los banners.
///
/// **Sin imagen se pinta la silueta del tipo, y nunca la de otro nivel.** El
/// logo de una marca no hace de foto de sus seis modelos: saldrían los seis con
/// la misma imagen, que es exactamente lo que no distingue nada. Un catálogo
/// recién cargado tiene que leerse sobrio, no averiado.
class ImagenDeVehiculo extends StatefulWidget {
  const ImagenDeVehiculo({
    super.key,
    required this.url,
    required this.icono,
    this.tamano = 44,
  });

  /// Imagen de la fila, o `null` si no tiene: las tres son opcionales.
  final String? url;

  /// El tipo al que pertenece la fila. De él sale la silueta de respaldo.
  final IconoVehiculo icono;

  /// Las dos cajas reales están declaradas en `compartido/gestion/imagenes.ts`:
  /// 44 en la fila del desplegable y 72 en lo elegido. La imagen es 1:1 por
  /// contrato de subida, así que la caja es cuadrada y no recorta nada.
  final double tamano;

  @override
  State<ImagenDeVehiculo> createState() => _ImagenDeVehiculoState();
}

class _ImagenDeVehiculoState extends State<ImagenDeVehiculo> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _traer();
  }

  @override
  void didUpdateWidget(ImagenDeVehiculo anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.url != widget.url) {
      _bytes = null;
      _traer();
    }
  }

  Future<void> _traer() async {
    final url = widget.url;
    if (url == null || url.isEmpty) {
      return; // No hay nada que pedir: se queda con la silueta.
    }
    final datos = await locator<BannerImageStore>().bytes(url);
    if (!mounted || datos == null) {
      return; // Un fallo deja la silueta, no un hueco gris.
    }
    setState(() => _bytes = datos);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: SizedBox(
        width: widget.tamano,
        height: widget.tamano,
        // La silueta ocupa exactamente el mismo espacio que ocuparía la imagen:
        // sin eso, la lista da un salto por cada foto que llega.
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover)
            : ColoredBox(
                color: AppColors.primarySurface,
                child: Icon(
                  widget.icono.silueta,
                  size: widget.tamano * 0.6,
                  color: AppColors.primary,
                ),
              ),
      ),
    );
  }
}

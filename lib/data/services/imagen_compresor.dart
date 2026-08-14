import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Recompresión de una foto para que quepa en un tope de peso antes de subirla.
///
/// La evidencia de entrega se toma **en la calle, con datos móviles y con el
/// cliente delante**. `image_picker` ya redimensiona y recodifica de forma nativa
/// al capturar (`maxWidth` + `imageQuality`), pero el resultado depende de la
/// cámara: la misma configuración da 180 KB en un teléfono y 900 KB en otro con
/// mejor sensor. Esta segunda pasada pone un techo conocido.
///
/// **Nunca bloquea una entrega.** Cualquier fallo —archivo ilegible, formato
/// exótico, memoria— devuelve el archivo original: subir 900 KB es peor que subir
/// 250 KB, pero infinitamente mejor que no poder cerrar el pedido.
class ImagenCompresor {
  const ImagenCompresor();

  /// Tope de peso por defecto. Una foto de entrega es la prueba de que el paquete
  /// llegó, no un documento que haya que leer.
  static const int topeBytesPorDefecto = 300 * 1024;

  /// Piso de calidad. Por debajo de esto la foto deja de servir como prueba, y
  /// una evidencia que no se puede mirar no es una evidencia.
  static const int calidadMinimaPorDefecto = 35;

  /// Devuelve un archivo que cabe en [topeBytes], o el más pequeño que se pudo
  /// conseguir sin bajar de [calidadMinima]. Si el original ya cabe, lo devuelve
  /// **tal cual** (misma ruta): no se recodifica por gusto.
  Future<File> aTope(
    File origen, {
    int topeBytes = topeBytesPorDefecto,
    int calidadMinima = calidadMinimaPorDefecto,
  }) async {
    try {
      final bytes = await origen.readAsBytes();
      if (bytes.length <= topeBytes) return origen;

      // En un isolate: decodificar y recodificar un JPEG de 1280 px son cientos
      // de milisegundos, y este código corre justo cuando el conductor acaba de
      // tocar el botón. En el hilo de UI se vería como un tirón de la animación.
      final comprimida = await compute(_recomprimir, (
        bytes,
        topeBytes,
        calidadMinima,
      ));
      // Si salió igual o más grande, se queda el original: recomprimir un JPEG ya
      // muy comprimido puede engordarlo.
      if (comprimida == null || comprimida.length >= bytes.length) {
        return origen;
      }

      final destino = File(_rutaComprimida(origen.path));
      await destino.writeAsBytes(comprimida, flush: true);
      return destino;
    } catch (_) {
      // Comprimir es una mejora, no un requisito de la entrega.
      return origen;
    }
  }

  /// Junto al original (directorio de caché de `image_picker`, escribible) y con
  /// extensión `.jpg`, que es lo que de verdad contiene después de recodificar.
  static String _rutaComprimida(String rutaOrigen) {
    final punto = rutaOrigen.lastIndexOf('.');
    final base = punto > 0 ? rutaOrigen.substring(0, punto) : rutaOrigen;
    return '$base-comprimida.jpg';
  }
}

/// Baja la calidad por pasos hasta caber en el tope o hasta tocar el piso.
///
/// Corre en un isolate, así que es una función de nivel superior y recibe un
/// registro de valores planos.
Uint8List? _recomprimir((Uint8List, int, int) peticion) {
  final (bytes, topeBytes, calidadMinima) = peticion;

  final decodificada = img.decodeImage(bytes);
  if (decodificada == null) return null;

  Uint8List? ultima;
  // Pasos de 10: cada uno recorta bastante peso y son pocas iteraciones. Bajar
  // de uno en uno multiplicaría el tiempo para afinar kilobytes que no se ven.
  for (var calidad = 70; calidad >= calidadMinima; calidad -= 10) {
    ultima = img.encodeJpg(decodificada, quality: calidad);
    if (ultima.length <= topeBytes) return ultima;
  }
  // No cupo ni al piso de calidad: se devuelve la más pequeña que se logró. Es
  // mejor que el original y sigue siendo mirable; degradarla más para cumplir un
  // número sería sacrificar la prueba por la métrica.
  return ultima;
}

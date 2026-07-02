import 'package:latlong2/latlong.dart';

/// Decodificador del formato *encoded polyline* de Google (precisión 5), que es
/// el que el backend persiste en `Pedido.rutaPolyline` (trayecto ORS
/// recogida→entrega). Se usa para trazar el recorrido en el mapa.
class PolylineCodec {
  const PolylineCodec._();

  /// Decodifica una polilínea codificada a una lista de puntos. Devuelve lista
  /// vacía si es null/vacía o malformada.
  static List<LatLng> decode(String? encoded, {int precision = 5}) {
    if (encoded == null || encoded.isEmpty) return const [];
    final points = <LatLng>[];
    final factor = _pow10(precision);
    int index = 0;
    int lat = 0;
    int lng = 0;
    final len = encoded.length;

    try {
      while (index < len) {
        int result = 1;
        int shift = 0;
        int b;
        do {
          b = encoded.codeUnitAt(index++) - 63 - 1;
          result += b << shift;
          shift += 5;
        } while (b >= 0x1f && index < len);
        lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

        result = 1;
        shift = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63 - 1;
          result += b << shift;
          shift += 5;
        } while (b >= 0x1f && index < len);
        lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

        points.add(LatLng(lat / factor, lng / factor));
      }
    } catch (_) {
      // Cadena malformada: devolvemos lo decodificado hasta el momento.
    }
    return points;
  }

  static double _pow10(int n) {
    var r = 1.0;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }
}

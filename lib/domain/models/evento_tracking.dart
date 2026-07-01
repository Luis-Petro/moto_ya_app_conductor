import 'package:latlong2/latlong.dart';

/// Evento recibido por el canal de tracking en tiempo real (`/topic/pedido/{id}`).
/// El backend emite `{tipo: ESTADO|POSICION, ...}`.
sealed class EventoTracking {
  const EventoTracking();

  static EventoTracking? fromJson(Map<String, dynamic> json) {
    switch (json['tipo']) {
      case 'ESTADO':
        final estado = json['estado'];
        if (estado is String) return EventoEstado(estado);
        return null;
      case 'POSICION':
        final lat = json['lat'];
        final lng = json['lng'];
        if (lat is num && lng is num) {
          return EventoPosicion(LatLng(lat.toDouble(), lng.toDouble()));
        }
        return null;
      default:
        return null;
    }
  }
}

class EventoEstado extends EventoTracking {
  const EventoEstado(this.estadoWire);
  final String estadoWire;
}

class EventoPosicion extends EventoTracking {
  const EventoPosicion(this.posicion);
  final LatLng posicion;
}

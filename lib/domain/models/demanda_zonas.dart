import 'package:latlong2/latlong.dart';

/// Nivel de demanda de una celda. Lo decide el servidor por terciles del
/// conteo, no la app: así todos los conductores ven la misma escala.
enum NivelDemanda {
  alta,
  media,
  baja;

  static NivelDemanda fromWire(String? v) => switch (v) {
        'ALTA' => NivelDemanda.alta,
        'MEDIA' => NivelDemanda.media,
        _ => NivelDemanda.baja,
      };

  String get label => switch (this) {
        NivelDemanda.alta => 'Alta',
        NivelDemanda.media => 'Media',
        NivelDemanda.baja => 'Baja',
      };
}

/// Una zona de la rejilla con su conteo de pedidos recientes.
class CeldaDemanda {
  const CeldaDemanda({
    required this.centro,
    required this.pedidos,
    required this.nivel,
  });

  final LatLng centro;
  final int pedidos;
  final NivelDemanda nivel;
}

/// Demanda reciente por zonas (`GET /matching/demanda`).
///
/// `celdas` viene vacía cuando no hay datos suficientes en el ámbito del
/// conductor: en ese caso la app muestra un vacío honesto, nunca un mapa
/// inventado.
class DemandaZonas {
  const DemandaZonas({
    required this.periodoHoras,
    required this.totalPedidos,
    required this.actualizadoEn,
    required this.celdas,
  });

  final int periodoHoras;
  final int totalPedidos;
  final DateTime actualizadoEn;
  final List<CeldaDemanda> celdas;

  bool get tieneDatos => celdas.isNotEmpty;
}

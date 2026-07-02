import 'package:latlong2/latlong.dart';

import 'categoria_servicio.dart';
import 'estado_pedido.dart';

/// Modelo de dominio del pedido.
class Pedido {
  const Pedido({
    required this.id,
    required this.clienteId,
    this.conductorId,
    required this.categoria,
    required this.descripcion,
    this.origen,
    this.destino,
    this.direccionRecogida,
    this.direccionDestino,
    this.referencia,
    this.fotoUrl,
    this.tarifaSugerida,
    this.tarifaEstimada = false,
    this.tarifaFinal,
    this.requiereCompra = false,
    this.montoCompraEstimado,
    required this.estado,
    this.motivoCancelacion,
    this.creadoEn,
    this.entregadoEn,
    this.clienteNombre,
    this.clienteTelefono,
    this.distanciaEstimadaMetros,
    this.duracionEstimadaSegundos,
    this.rutaPolyline,
  });

  final int id;
  final int clienteId;
  final int? conductorId;
  final CategoriaServicio categoria;
  final String descripcion;
  /// Punto de recogida (dónde el conductor recoge/compra).
  final LatLng? origen;

  /// Punto de entrega.
  final LatLng? destino;
  final String? direccionRecogida;
  final String? direccionDestino;
  final String? referencia;
  final String? fotoUrl;
  final double? tarifaSugerida;

  /// True cuando la tarifa sugerida proviene de un cálculo de respaldo
  /// (ORS no disponible) y es solo una estimación.
  final bool tarifaEstimada;
  final double? tarifaFinal;

  /// El conductor debe adelantar dinero para comprar algo.
  final bool requiereCompra;

  /// Monto estimado de la compra que el cliente reembolsa (no comisionable).
  final double? montoCompraEstimado;
  final EstadoPedido estado;
  final String? motivoCancelacion;
  final DateTime? creadoEn;
  final DateTime? entregadoEn;

  /// Datos de contacto del cliente para el pedido activo (design Q6). Pueden
  /// venir en el detalle del pedido para el conductor asignado.
  final String? clienteNombre;
  final String? clienteTelefono;

  // ── Ruta estimada recogida→entrega (ORS, calculada al crear el pedido) ──
  /// Distancia del trayecto en metros (null si ORS no respondió).
  final double? distanciaEstimadaMetros;

  /// Duración estimada del trayecto en segundos (null si ORS no respondió).
  final double? duracionEstimadaSegundos;

  /// Polilínea codificada (Google, precisión 5) del trayecto recogida→entrega.
  final String? rutaPolyline;

  bool get tieneConductor => conductorId != null;

  /// Ganancia neta del conductor sobre una tarifa dada (servicio − comisión 15%).
  /// El backend fija la comisión efectiva al entregar; esto es solo para mostrar.
  static double gananciaNeta(double tarifa) => tarifa * 0.85;

  /// Comisión de plataforma (15% del servicio) sobre una tarifa dada.
  static double comision(double tarifa) => tarifa * 0.15;
}

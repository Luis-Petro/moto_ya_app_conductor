import 'package:latlong2/latlong.dart';

import 'categoria_servicio.dart';
import 'estado_pedido.dart';
import 'item_pedido.dart';

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
    this.referenciaRecogida,
    this.referencia,
    this.fotoUrl,
    this.tarifaSugerida,
    this.tarifaEstimada = false,
    this.tarifaFinal,
    this.recargoAdelanto,
    this.recargoEspera,
    this.requiereCompra = false,
    this.montoCompraEstimado,
    this.pedidosConAdelantoDelCliente,
    this.requiereEspera = false,
    this.minutosEsperaEstimados,
    required this.estado,
    this.motivoCancelacion,
    this.creadoEn,
    this.entregadoEn,
    this.clienteNombre,
    this.clienteTelefono,
    this.clienteFotoUrl,
    this.distanciaEstimadaMetros,
    this.duracionEstimadaSegundos,
    this.rutaPolyline,
    this.items = const [],
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

  /// Referencia del punto de recogida (local, esquina, color de la fachada…):
  /// lo que le ahorra vueltas al conductor al llegar.
  final String? referenciaRecogida;

  /// Referencia del punto de entrega.
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

  /// Cuántos pedidos con compra adelantada ha completado este cliente.
  ///
  /// Es quien va a poner la plata el que decide: un tope que resuelve el sistema
  /// en silencio le quita la última palabra a quien asume el riesgo. Solo llega
  /// en pedidos **con compra adelantada** — sin plata de por medio es un dato
  /// sobre una persona que no hace falta para decidir.
  ///
  /// Es un **agregado y nada más**: ni identidad del cliente, ni su tope, ni
  /// ninguna marca de impago. `null` cuando el backend no lo manda (una versión
  /// anterior), y entonces la tarjeta simplemente no pinta el rótulo.
  final int? pedidosConAdelantoDelCliente;

  /// Hay que esperar o hacer cola en la recogida (el cliente lo declaró).
  final bool requiereEspera;

  /// Minutos de espera declarados: la base con la que se calculó el recargo.
  final int? minutosEsperaEstimados;

  /// Desglose de la tarifa: recargo por adelantar la compra (sí es comisionable,
  /// a diferencia del monto de la compra en sí).
  final double? recargoAdelanto;

  /// Desglose de la tarifa: recargo por espera, por bloques iniciados.
  final double? recargoEspera;

  final EstadoPedido estado;
  final String? motivoCancelacion;
  final DateTime? creadoEn;
  final DateTime? entregadoEn;

  /// Datos de contacto del cliente para el pedido activo (design Q6). Pueden
  /// venir en el detalle del pedido para el conductor asignado.
  final String? clienteNombre;
  final String? clienteTelefono;

  /// Foto del cliente (la del perfil). Solo llega con el contacto, es decir,
  /// cuando el conductor ya tiene el pedido asignado.
  final String? clienteFotoUrl;

  // ── Ruta estimada recogida→entrega (ORS, calculada al crear el pedido) ──
  /// Distancia del trayecto en metros (null si ORS no respondió).
  final double? distanciaEstimadaMetros;

  /// Duración estimada del trayecto en segundos (null si ORS no respondió).
  final double? duracionEstimadaSegundos;

  /// Polilínea codificada (Google, precisión 5) del trayecto recogida→entrega.
  final String? rutaPolyline;

  /// Los artículos del catálogo que el cliente eligió, si el pedido salió de un
  /// negocio afiliado. **Vacía en un pedido escrito a mano**, que sigue siendo el
  /// camino principal: la lista es un extra sobre la descripción, no la sustituye.
  ///
  /// Solo llega en `PedidoDetalleResponse` (el detalle, el avance, el activo) y no
  /// en la entidad cruda de `/pedidos/asignados`, así que el historial la ve vacía
  /// y eso no es un fallo.
  final List<ItemPedido> items;

  bool get tieneItems => items.isNotEmpty;

  /// Copia con campos sustituidos. Reconstruir el pedido a mano campo por campo
  /// hacía que cualquier campo nuevo se perdiera en silencio (así desaparecía el
  /// contacto del cliente al avanzar de estado).
  Pedido copyWith({
    EstadoPedido? estado,
    String? clienteNombre,
    String? clienteTelefono,
    String? clienteFotoUrl,
    double? tarifaFinal,
  }) {
    return Pedido(
      id: id,
      clienteId: clienteId,
      conductorId: conductorId,
      categoria: categoria,
      descripcion: descripcion,
      origen: origen,
      destino: destino,
      direccionRecogida: direccionRecogida,
      direccionDestino: direccionDestino,
      referenciaRecogida: referenciaRecogida,
      referencia: referencia,
      fotoUrl: fotoUrl,
      tarifaSugerida: tarifaSugerida,
      tarifaEstimada: tarifaEstimada,
      tarifaFinal: tarifaFinal ?? this.tarifaFinal,
      recargoAdelanto: recargoAdelanto,
      recargoEspera: recargoEspera,
      requiereCompra: requiereCompra,
      montoCompraEstimado: montoCompraEstimado,
      pedidosConAdelantoDelCliente: pedidosConAdelantoDelCliente,
      requiereEspera: requiereEspera,
      minutosEsperaEstimados: minutosEsperaEstimados,
      estado: estado ?? this.estado,
      motivoCancelacion: motivoCancelacion,
      creadoEn: creadoEn,
      entregadoEn: entregadoEn,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
      clienteFotoUrl: clienteFotoUrl ?? this.clienteFotoUrl,
      distanciaEstimadaMetros: distanciaEstimadaMetros,
      duracionEstimadaSegundos: duracionEstimadaSegundos,
      rutaPolyline: rutaPolyline,
      items: items,
    );
  }

  bool get tieneConductor => conductorId != null;

  /// Componente por distancia de la tarifa: el total menos los recargos.
  double? get tarifaDistancia {
    final total = tarifaFinal ?? tarifaSugerida;
    if (total == null) return null;
    return total - (recargoAdelanto ?? 0) - (recargoEspera ?? 0);
  }

  /// Hay algo que desglosar (si no, basta con el total).
  bool get tieneRecargos =>
      (recargoAdelanto ?? 0) > 0 || (recargoEspera ?? 0) > 0;

  /// Ganancia neta del conductor sobre una tarifa dada (servicio − comisión 15%).
  /// El backend fija la comisión efectiva al entregar; esto es solo para mostrar.
  static double gananciaNeta(double tarifa) => tarifa * 0.85;

  /// Comisión de plataforma (15% del servicio) sobre una tarifa dada.
  static double comision(double tarifa) => tarifa * 0.15;
}

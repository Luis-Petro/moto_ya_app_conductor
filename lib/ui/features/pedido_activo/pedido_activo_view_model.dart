import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/repositories/pedido_repository.dart';
import '../../../data/services/location_reporter.dart';
import '../../../data/services/tracking_service.dart';
import '../../../domain/models/estado_pedido.dart';
import '../../../domain/models/evento_tracking.dart';
import '../../../domain/models/pedido.dart';

/// Estado del pedido activo: detalle, avance de estados 1-tap, evidencia y
/// publicación de posición GPS en vivo por STOMP.
class PedidoActivoViewModel extends ChangeNotifier {
  PedidoActivoViewModel(this._pedidos, this._tracking, this.pedidoId)
      : _reporter = LocationReporter();

  final PedidoRepository _pedidos;
  final TrackingService _tracking;
  final LocationReporter _reporter;
  final int pedidoId;

  bool cargando = true;
  bool procesando = false;
  String? error;
  Pedido? pedido;
  LatLng? posicion;

  StreamSubscription<EventoTracking>? _sub;

  EstadoPedido get estado => pedido?.estado ?? EstadoPedido.aceptado;
  bool get entregado => estado == EstadoPedido.entregado;

  /// Próximo estado según la máquina de estados; null si ya no hay avance 1-tap.
  EstadoPedido? get proximoEstado {
    switch (estado) {
      case EstadoPedido.aceptado:
        return EstadoPedido.enCompra;
      case EstadoPedido.enCompra:
        return EstadoPedido.enCamino;
      case EstadoPedido.enCamino:
        return EstadoPedido.entregado;
      default:
        return null;
    }
  }

  String get etiquetaAvance {
    switch (proximoEstado) {
      case EstadoPedido.enCompra:
        return 'Marcar: En compra';
      case EstadoPedido.enCamino:
        return 'Marcar: En camino';
      case EstadoPedido.entregado:
        return 'Marcar: Entregado';
      default:
        return 'Pedido completado';
    }
  }

  Future<void> cargar() async {
    cargando = true;
    notifyListeners();
    final res = await _pedidos.detalle(pedidoId);
    res.when(ok: (p) => pedido = p, err: (f) => error = f.message);
    cargando = false;
    notifyListeners();
    if (pedido != null && !pedido!.estado.esFinal) {
      _suscribirTracking();
      _publicarPosicion();
    }
  }

  void _suscribirTracking() {
    _sub?.cancel();
    _sub = _tracking.connect(pedidoId).listen((evento) {
      if (evento is EventoEstado) {
        final nuevo = EstadoPedido.fromWire(evento.estadoWire);
        pedido = _conEstado(nuevo);
        notifyListeners();
        if (nuevo.esFinal) _detenerTracking();
      }
    });
  }

  void _publicarPosicion() {
    _reporter.start((punto) {
      posicion = punto;
      // REST es el canal real: el backend retransmite por STOMP al cliente.
      _pedidos.reportarPosicion(pedidoId, punto);
      notifyListeners();
    });
  }

  /// Avanza el estado del pedido (EN_COMPRA → EN_CAMINO). Para la entrega usar
  /// [entregar].
  Future<bool> avanzar() async {
    final destino = proximoEstado;
    if (destino == null || destino == EstadoPedido.entregado) return false;
    procesando = true;
    notifyListeners();
    final res = await _pedidos.avanzar(pedidoId, destino);
    procesando = false;
    final ok = res.isSuccess;
    if (ok) {
      pedido = res.valueOrNull ?? _conEstado(destino);
    } else {
      error = res.when(ok: (_) => null, err: (f) => f.message);
    }
    notifyListeners();
    return ok;
  }

  /// Marca el pedido entregado con evidencia opcional.
  Future<bool> entregar({File? foto}) async {
    procesando = true;
    notifyListeners();
    MultipartFile? multipart;
    if (foto != null) multipart = await MultipartFile.fromFile(foto.path);
    final res = await _pedidos.entregar(
      pedidoId,
      foto: multipart,
      coordenadas: posicion,
    );
    procesando = false;
    final ok = res.isSuccess;
    if (ok) {
      pedido = res.valueOrNull ?? _conEstado(EstadoPedido.entregado);
      _detenerTracking();
    } else {
      error = res.when(ok: (_) => null, err: (f) => f.message);
    }
    notifyListeners();
    return ok;
  }

  Pedido? _conEstado(EstadoPedido nuevo) {
    final p = pedido;
    if (p == null) return null;
    return Pedido(
      id: p.id,
      clienteId: p.clienteId,
      conductorId: p.conductorId,
      categoria: p.categoria,
      descripcion: p.descripcion,
      origen: p.origen,
      destino: p.destino,
      direccionRecogida: p.direccionRecogida,
      direccionDestino: p.direccionDestino,
      referencia: p.referencia,
      fotoUrl: p.fotoUrl,
      tarifaSugerida: p.tarifaSugerida,
      tarifaEstimada: p.tarifaEstimada,
      tarifaFinal: p.tarifaFinal,
      requiereCompra: p.requiereCompra,
      montoCompraEstimado: p.montoCompraEstimado,
      estado: nuevo,
      motivoCancelacion: p.motivoCancelacion,
      creadoEn: p.creadoEn,
      entregadoEn: p.entregadoEn,
      clienteNombre: p.clienteNombre,
      clienteTelefono: p.clienteTelefono,
    );
  }

  void _detenerTracking() {
    _reporter.stop();
    _sub?.cancel();
    _sub = null;
    _tracking.disconnect();
  }

  @override
  void dispose() {
    _detenerTracking();
    super.dispose();
  }
}

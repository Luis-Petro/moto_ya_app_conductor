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

  /// Si el último error fue de red. La vista lo necesita para no decirle
  /// "revisa tu internet" a quien recibió un rechazo del servidor.
  bool errorEsRed = false;
  Pedido? pedido;
  LatLng? posicion;

  StreamSubscription<EventoTracking>? _sub;

  EstadoPedido get estado => pedido?.estado ?? EstadoPedido.aceptado;
  bool get entregado => estado == EstadoPedido.entregado;

  /// Antes de EN_CAMINO el conductor va hacia la recogida/compra; después, a la
  /// entrega (misma regla que usa el backend para el objetivo del ETA).
  bool get vaARecogida =>
      estado == EstadoPedido.aceptado || estado == EstadoPedido.enCompra;

  /// Punto al que debe dirigirse ahora (para "Cómo llegar" y centrar el mapa).
  LatLng? get puntoObjetivo =>
      vaARecogida ? (pedido?.origen ?? pedido?.destino) : pedido?.destino;

  String get etiquetaObjetivo =>
      vaARecogida ? 'punto de recogida' : 'punto de entrega';

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

  /// Qué dice el botón grande de abajo.
  ///
  /// Dice **lo que el conductor acaba de hacer**, en primera persona, y no el
  /// nombre del estado al que pasa el pedido. "Marcar: En camino" obligaba a
  /// traducir: ¿marco que *voy* en camino o que *ya estuve*? "Ya tengo el
  /// pedido" no necesita traducción: o lo tiene en la mano o no.
  String get etiquetaAvance {
    final compra = pedido?.requiereCompra ?? false;
    switch (proximoEstado) {
      case EstadoPedido.enCompra:
        return compra ? 'Ya llegué al negocio' : 'Ya llegué a recoger';
      case EstadoPedido.enCamino:
        return compra ? 'Ya compré, voy a entregar' : 'Ya lo tengo, voy a entregar';
      case EstadoPedido.entregado:
        return 'Ya entregué el pedido';
      default:
        return 'Pedido completado';
    }
  }

  /// La línea que va sobre el botón: **cuándo** tocarlo.
  ///
  /// El botón cambia el pedido para el cliente y no se puede deshacer. Quien no
  /// está acostumbrado a la app no lo toca por miedo, o lo toca antes de tiempo;
  /// las dos cosas se arreglan diciendo el momento exacto.
  String get cuandoAvanzar {
    final compra = pedido?.requiereCompra ?? false;
    switch (proximoEstado) {
      case EstadoPedido.enCompra:
        return compra
            ? 'Tócalo cuando estés en el negocio.'
            : 'Tócalo cuando estés en el sitio de recogida.';
      case EstadoPedido.enCamino:
        return 'Tócalo cuando tengas el pedido contigo.';
      case EstadoPedido.entregado:
        return 'Tócalo cuando el cliente tenga el pedido en la mano.';
      default:
        return '';
    }
  }

  /// Número del paso actual (1 a 3) de lo que hace el conductor:
  /// ir a recoger → recoger/comprar → llevar al cliente.
  int get pasoActual => switch (estado) {
        EstadoPedido.aceptado => 1,
        EstadoPedido.enCompra => 2,
        EstadoPedido.enCamino => 3,
        _ => 3,
      };

  static const int totalPasos = 3;

  /// Rumbo del último desplazamiento real, en grados (0 = norte, 90 = este).
  ///
  /// Solo sirve para voltear la moto del mapa hacia donde va. Se recalcula con
  /// desplazamientos de más de [_metrosParaRumbo]: el GPS parado "tiembla" unos
  /// metros, y con cada temblor la moto se daría la vuelta sola.
  double? rumbo;
  LatLng? _ultimoPuntoRumbo;
  static const double _metrosParaRumbo = 8;
  static const Distance _distancia = Distance();

  void _actualizarRumbo(LatLng punto) {
    final previo = _ultimoPuntoRumbo;
    if (previo == null) {
      _ultimoPuntoRumbo = punto;
      return;
    }
    if (_distancia.as(LengthUnit.Meter, previo, punto) < _metrosParaRumbo) {
      return;
    }
    rumbo = (_distancia.bearing(previo, punto) + 360) % 360;
    _ultimoPuntoRumbo = punto;
  }

  Future<void> cargar() async {
    cargando = true;
    notifyListeners();
    final res = await _pedidos.detalle(pedidoId);
    res.when(
      ok: (p) {
        pedido = p;
        error = null;
        errorEsRed = false;
      },
      err: (f) {
        error = f.message;
        errorEsRed = f.isNetwork;
      },
    );
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
        pedido = pedido?.copyWith(estado: nuevo);
        notifyListeners();
        if (nuevo.esFinal) _detenerTracking();
      }
    });
  }

  void _publicarPosicion() {
    _reporter.start((punto) {
      posicion = punto;
      _actualizarRumbo(punto);
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
      pedido = res.valueOrNull ?? pedido?.copyWith(estado: destino);
    } else {
      error = res.when(ok: (_) => null, err: (f) => f.message);
    }
    notifyListeners();
    return ok;
  }

  /// Fracción subida de la evidencia, 0..1. Nula cuando no hay subida en curso
  /// **o cuando Dio no informa el total**: un porcentaje inventado es peor que
  /// ninguno, porque el conductor decide si esperar mirándolo.
  double? progresoSubida;

  /// Bytes que se están subiendo, para poder decir *cuánto* pesa lo que espera.
  int? bytesSubiendo;

  /// Marca el pedido entregado con evidencia opcional.
  ///
  /// Si la subida de la foto falla, **el pedido no avanza** y la foto sigue en
  /// pantalla para reintentar: es la prueba con la que se resuelve una disputa, y
  /// perderla en silencio era el comportamiento anterior.
  /// [montoRealProductos] es lo que el negocio cobró de verdad por los productos,
  /// y es **opcional a propósito**: si el conductor lo deja vacío la entrega sigue
  /// su curso con el estimado del catálogo. Un campo obligatorio aquí sería un
  /// trámite entre él y cobrar, con el cliente esperando en la puerta.
  /// [adelantoNoReembolsado] va **fuera del JSON cuando es nulo**: «no dijo
  /// nada» y «dijo que sí le pagaron» son cosas distintas, y el silencio de todo
  /// el mundo no puede convertirse en una afirmación. Tampoco bloquea entregar.
  Future<bool> entregar({
    File? foto,
    double? montoRealProductos,
    bool? adelantoNoReembolsado,
  }) async {
    procesando = true;
    error = null;
    progresoSubida = null;
    bytesSubiendo = null;
    notifyListeners();

    MultipartFile? multipart;
    if (foto != null) {
      multipart = await MultipartFile.fromFile(foto.path);
      bytesSubiendo = await foto.length();
    }

    final res = await _pedidos.entregar(
      pedidoId,
      foto: multipart,
      coordenadas: posicion,
      montoRealProductos: montoRealProductos,
      adelantoNoReembolsado: adelantoNoReembolsado,
      onProgreso: multipart == null
          ? null
          : (enviados, total) {
              // Dio manda `-1` cuando no conoce el total.
              progresoSubida = total > 0
                  ? (enviados / total).clamp(0, 1)
                  : null;
              notifyListeners();
            },
    );

    procesando = false;
    progresoSubida = null;
    bytesSubiendo = null;
    final ok = res.isSuccess;
    if (ok) {
      pedido =
          res.valueOrNull ?? pedido?.copyWith(estado: EstadoPedido.entregado);
      _detenerTracking();
    } else {
      error = res.when(ok: (_) => null, err: (f) => f.message);
    }
    notifyListeners();
    return ok;
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

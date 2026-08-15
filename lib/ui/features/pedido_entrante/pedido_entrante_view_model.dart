import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/pedido_repository.dart';
import '../../../data/services/ofertas_service.dart';
import '../../../domain/models/oferta.dart';
import '../../../domain/models/pedido.dart';

enum EstadoEntrante {
  cargando,
  disponible,

  /// La oferta se abrió pero ya no se puede responder (venció el reloj, o el
  /// pedido se cerró estando la tarjeta abierta). El pedido sigue a la vista.
  expirado,

  /// El pedido ya no es suyo y el backend no lo deja ni verlo: otro conductor lo
  /// tomó o el cliente lo canceló. Estado **terminal**: no hay nada que
  /// reintentar y no hay pedido que pintar.
  noDisponible,

  error,
}

/// Estado de la tarjeta de pedido entrante: detalle, temporizador de respuesta
/// (con la ventana real del servidor) y desglose económico con recálculo por
/// contraoferta. Cierra la tarjeta en tiempo real si el pedido es tomado por
/// otro, expira o se cancela.
class PedidoEntranteViewModel extends ChangeNotifier {
  PedidoEntranteViewModel(this._pedidos, this.pedidoId, this._ofertas,
      {this.segundosIniciales}) {
    _suscribirEventos();
  }

  final PedidoRepository _pedidos;
  final OfertasService _ofertas;
  final int pedidoId;

  /// Ventana que trajo el evento STOMP, si la tarjeta se abrió desde él. Si es
  /// null (deep link, push, reapertura) se resuelve contra `/pedidos/ofertas`:
  /// no existe un default de 30 s en la app, porque la ventana la fija el
  /// backend (`MATCHING_TIMEOUT_SEGUNDOS`, editable en runtime) y un número
  /// inventado aquí haría correr un reloj que no es el que decide.
  final int? segundosIniciales;

  EstadoEntrante estado = EstadoEntrante.cargando;
  String? error;

  /// Si el último error fue de red. La vista lo necesita para no decirle
  /// "revisa tu internet" a quien recibió un rechazo del servidor.
  bool errorEsRed = false;

  /// Aviso al cerrarse la oferta de forma remota (tomada/cancelada), para el
  /// encabezado. Null cuando simplemente expiró el tiempo.
  String? avisoCierre;
  Pedido? pedido;

  int segundosRestantes = 0;

  /// Ventana completa concedida por el servidor, para dibujar cuánto queda del
  /// tiempo (no solo el número): una barra que se vacía comunica la urgencia
  /// sin que el conductor tenga que leer y restar.
  int ventanaTotal = 0;

  /// Proporción de la ventana que aún queda (1 → recién llegada, 0 → vencida).
  double get fraccionTiempo => ventanaTotal <= 0
      ? 0
      : (segundosRestantes / ventanaTotal).clamp(0.0, 1.0);

  /// Fin local de la ventana = ahora + segundos del servidor. Basar el countdown
  /// en esto (no en un contador que se decrementa) lo hace inmune al reloj
  /// desfasado del teléfono y al tiempo en segundo plano.
  DateTime? _finLocal;
  Timer? _timer;
  StreamSubscription<EventoOferta>? _eventoSub;

  bool enviando = false;
  bool rechazando = false;

  /// Monto propuesto por el conductor (para contraoferta). Inicia en la sugerida.
  double montoPropuesto = 0;

  double get tarifaSugerida => pedido?.tarifaSugerida ?? 0;
  double get comision => Pedido.comision(montoPropuesto);
  double get gananciaNeta => Pedido.gananciaNeta(montoPropuesto);
  bool get esContraoferta => montoPropuesto != tarifaSugerida;

  Future<void> cargar() async {
    estado = EstadoEntrante.cargando;
    notifyListeners();

    final segundos = segundosIniciales ?? await _ventanaDelServidor();

    final res = await _pedidos.detalle(pedidoId);
    res.when(
      ok: (p) {
        pedido = p;
        montoPropuesto = p.tarifaSugerida ?? 0;
        if (segundos == null || segundos <= 0) {
          // No hay oferta vigente para este conductor: el pedido puede verse,
          // pero proponer devolvería 409. Mejor decirlo de entrada que dejarlo
          // intentar contra un reloj que no existe.
          ventanaTotal = 0;
          segundosRestantes = 0;
          estado = EstadoEntrante.expirado;
          avisoCierre ??= 'La oferta ya no está vigente';
        } else {
          ventanaTotal = segundos;
          segundosRestantes = segundos;
          estado = EstadoEntrante.disponible;
          _iniciarTemporizador();
        }
      },
      err: (f) {
        // 403 = "no participas en este pedido": lo tomó otro conductor o el
        // cliente lo canceló. 404 = ya no existe. En los dos casos la respuesta
        // va a ser la misma todas las veces, así que no se ofrece reintentar:
        // un botón que no puede funcionar enseña a desconfiar de los botones.
        if (f.statusCode == 403 || f.statusCode == 404) {
          estado = EstadoEntrante.noDisponible;
        } else {
          error = f.message;
          errorEsRed = f.isNetwork;
          estado = EstadoEntrante.error;
        }
      },
    );
    notifyListeners();
  }

  /// Por qué esta oferta ya no está.
  ///
  /// Si la app llegó a recibir el evento por STOMP, se nombra la causa. Abriendo
  /// en frío desde la notificación no hay evento previo y el 403 **no distingue**
  /// entre "la tomó otro" y "el cliente canceló": se dicen las dos. Escoger una
  /// haría que el conductor sacara conclusiones sobre su velocidad de respuesta
  /// a partir de un dato inventado.
  String get motivoNoDisponible =>
      avisoCierre ??
      'Puede que otro conductor la tomara o que el cliente cancelara el pedido.';

  /// Segundos que le quedan a la oferta de este pedido según el servidor, o
  /// null si ya no figura entre las ofertas vigentes del conductor.
  Future<int?> _ventanaDelServidor() async {
    final res = await _pedidos.ofertas();
    final lista = res.valueOrNull;
    if (lista == null) return null;
    for (final o in lista) {
      if (o.pedidoId == pedidoId) return o.segundosRestantes;
    }
    return null;
  }

  void _iniciarTemporizador() {
    _timer?.cancel();
    _finLocal = DateTime.now().add(Duration(seconds: segundosRestantes));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final restante = _finLocal!.difference(DateTime.now()).inSeconds;
      segundosRestantes = restante < 0 ? 0 : restante;
      if (restante <= 0) {
        _timer?.cancel();
        if (estado == EstadoEntrante.disponible) estado = EstadoEntrante.expirado;
      }
      notifyListeners();
    });
  }

  /// Cierra la tarjeta al recibir por STOMP que el pedido ya no es tomable.
  void _suscribirEventos() {
    _eventoSub = _ofertas.connect().listen((e) {
      if (e.pedidoId != pedidoId || !e.tipo.cierraOferta) return;
      _timer?.cancel();
      // Si el detalle ya vino denegado no hay pedido que pintar: el evento solo
      // aporta el motivo, y pasar a `expirado` dejaría la pantalla sin datos.
      if (estado != EstadoEntrante.noDisponible) {
        estado = EstadoEntrante.expirado;
      }
      avisoCierre = switch (e.tipo) {
        TipoEventoOferta.tomado => 'El pedido fue tomado por otro conductor',
        TipoEventoOferta.cancelado => 'El cliente canceló el pedido',
        _ => 'La oferta expiró',
      };
      notifyListeners();
    });
  }

  void ajustarMonto(double delta) {
    final nuevo = (montoPropuesto + delta);
    if (nuevo < 1000) return; // piso razonable
    montoPropuesto = nuevo;
    notifyListeners();
  }

  /// Acepta la tarifa sugerida (sin valor) o envía la contraoferta.
  Future<bool> enviarPropuesta({required bool aceptarSugerida}) async {
    if (estado == EstadoEntrante.expirado) return false;
    enviando = true;
    notifyListeners();
    final res = await _pedidos.proponer(
      pedidoId,
      valor: aceptarSugerida ? null : montoPropuesto,
    );
    enviando = false;
    final ok = res.isSuccess;
    if (!ok) {
      error = res.when(ok: (_) => null, err: (f) => f.message);
      // Un fallo (409) suele significar que el pedido ya fue tomado o la oferta
      // venció: refresca estado y cierra la tarjeta.
      await _refrescarSiConflicto();
    }
    notifyListeners();
    return ok;
  }

  /// Rechaza la oferta: se registra en el backend para no volver a ofrecerla y
  /// para reflejarlo en la tasa de aceptación. Devuelve true si se registró.
  Future<bool> rechazar() async {
    rechazando = true;
    notifyListeners();
    final res = await _pedidos.rechazar(pedidoId);
    rechazando = false;
    final ok = res.isSuccess;
    if (!ok) {
      error = res.when(ok: (_) => null, err: (f) => f.message);
    }
    notifyListeners();
    return ok;
  }

  Future<void> _refrescarSiConflicto() async {
    final res = await _pedidos.detalle(pedidoId);
    final p = res.valueOrNull;
    if (p != null && !p.estado.estaActivo) {
      estado = EstadoEntrante.expirado;
      avisoCierre ??= 'El pedido ya no está disponible';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _eventoSub?.cancel();
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/pedido_repository.dart';
import '../../../data/services/ofertas_service.dart';
import '../../../domain/models/oferta.dart';
import '../../../domain/models/pedido.dart';

enum EstadoEntrante { cargando, disponible, expirado, error }

/// Estado de la tarjeta de pedido entrante: detalle, temporizador de respuesta
/// (con la ventana real del servidor) y desglose económico con recálculo por
/// contraoferta. Cierra la tarjeta en tiempo real si el pedido es tomado por
/// otro, expira o se cancela.
class PedidoEntranteViewModel extends ChangeNotifier {
  PedidoEntranteViewModel(this._pedidos, this.pedidoId, this._ofertas,
      {int? segundosIniciales})
      : segundosRestantes = segundosIniciales ?? ventanaSegundos {
    _suscribirEventos();
  }

  final PedidoRepository _pedidos;
  final OfertasService _ofertas;
  final int pedidoId;

  /// Ventana de respaldo si el servidor no proveyó `segundosRestantes` (p. ej.
  /// al abrir por deep link). El backend usa el mismo default.
  static const int ventanaSegundos = 30;

  EstadoEntrante estado = EstadoEntrante.cargando;
  String? error;

  /// Aviso al cerrarse la oferta de forma remota (tomada/cancelada), para el
  /// encabezado. Null cuando simplemente expiró el tiempo.
  String? avisoCierre;
  Pedido? pedido;

  int segundosRestantes;

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
    final res = await _pedidos.detalle(pedidoId);
    res.when(
      ok: (p) {
        pedido = p;
        montoPropuesto = p.tarifaSugerida ?? 0;
        estado = EstadoEntrante.disponible;
        _iniciarTemporizador();
      },
      err: (f) {
        error = f.message;
        estado = EstadoEntrante.error;
      },
    );
    notifyListeners();
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
      estado = EstadoEntrante.expirado;
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

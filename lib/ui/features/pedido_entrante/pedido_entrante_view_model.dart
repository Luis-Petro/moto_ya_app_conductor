import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/pedido_repository.dart';
import '../../../domain/models/pedido.dart';

enum EstadoEntrante { cargando, disponible, expirado, error }

/// Estado de la tarjeta de pedido entrante: detalle, temporizador de respuesta
/// y desglose económico con recálculo por contraoferta.
class PedidoEntranteViewModel extends ChangeNotifier {
  PedidoEntranteViewModel(this._pedidos, this.pedidoId);

  final PedidoRepository _pedidos;
  final int pedidoId;

  /// Ventana de respuesta (mock 7 muestra ~0:24). Sin deadline del backend en
  /// el MVP se usa una ventana fija desde que se abre la tarjeta.
  static const int ventanaSegundos = 30;

  EstadoEntrante estado = EstadoEntrante.cargando;
  String? error;
  Pedido? pedido;

  int segundosRestantes = ventanaSegundos;
  Timer? _timer;

  bool enviando = false;

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
    segundosRestantes = ventanaSegundos;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (segundosRestantes <= 0) {
        t.cancel();
        estado = EstadoEntrante.expirado;
      } else {
        segundosRestantes--;
      }
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
      // Un fallo puede significar que el pedido ya fue tomado: refresca estado.
      await _refrescarSiConflicto();
    }
    notifyListeners();
    return ok;
  }

  Future<void> _refrescarSiConflicto() async {
    final res = await _pedidos.detalle(pedidoId);
    final p = res.valueOrNull;
    if (p != null && !p.estado.estaActivo) {
      estado = EstadoEntrante.expirado;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

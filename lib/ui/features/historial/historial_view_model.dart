import 'package:flutter/foundation.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../domain/models/conductor.dart';
import '../../../domain/models/estado_pedido.dart';
import '../../../domain/models/pedido.dart';

/// Estado del Historial: ingresos de la semana, pedidos recientes y reputación.
class HistorialViewModel extends ChangeNotifier {
  HistorialViewModel(this._pedidos, this._conductores);

  final PedidoRepository _pedidos;
  final ConductorRepository _conductores;

  bool cargando = true;
  String? error;

  List<Pedido> recientes = const [];

  /// Ganancia por día de la semana (índice 0 = lunes .. 6 = domingo).
  List<double> ingresosSemana = List.filled(7, 0);
  double totalSemana = 0;
  int totalPedidos = 0;

  Conductor? get conductor => _conductores.conductor;
  double? get calificacion => conductor?.calificacion;
  double? get tasaAceptacion => conductor?.tasaAceptacion;

  Future<void> cargar() async {
    cargando = true;
    error = null;
    notifyListeners();
    await _conductores.cargar();
    final res = await _pedidos.mios();
    res.when(
      ok: (lista) {
        final entregados =
            lista.where((p) => p.estado == EstadoPedido.entregado).toList();
        totalPedidos = entregados.length;
        recientes = entregados.take(20).toList();
        _calcularSemana(entregados);
      },
      err: (f) => error = f.message,
    );
    cargando = false;
    notifyListeners();
  }

  void _calcularSemana(List<Pedido> entregados) {
    final semana = List.filled(7, 0.0);
    final ahora = DateTime.now();
    final inicioSemana = DateTime(ahora.year, ahora.month, ahora.day)
        .subtract(Duration(days: ahora.weekday - 1));
    var total = 0.0;
    for (final p in entregados) {
      final f = p.entregadoEn?.toLocal();
      if (f == null || f.isBefore(inicioSemana)) continue;
      final dia = f.weekday - 1; // 0..6
      if (dia < 0 || dia > 6) continue;
      final ganancia = Pedido.gananciaNeta(p.tarifaFinal ?? p.tarifaSugerida ?? 0);
      semana[dia] += ganancia;
      total += ganancia;
    }
    ingresosSemana = semana;
    totalSemana = total;
  }
}

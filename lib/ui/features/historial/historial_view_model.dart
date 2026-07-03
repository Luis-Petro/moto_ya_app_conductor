import 'package:flutter/foundation.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../domain/models/conductor.dart';
import '../../../domain/models/estado_pedido.dart';
import '../../../domain/models/pedido.dart';
import '../../core/format/formato.dart';
import '../../core/tab_activa.dart';

/// Pedidos de un mismo día con su etiqueta ("Hoy"/"Ayer"/fecha) y la ganancia
/// total del día (cifra del separador).
class GrupoDia {
  const GrupoDia({
    required this.etiqueta,
    required this.total,
    required this.pedidos,
  });

  final String etiqueta;
  final double total;
  final List<Pedido> pedidos;
}

/// Estado del Historial: ingresos de la semana, pedidos recientes agrupados por
/// día y reputación. Se refresca solo cuando su tab vuelve a ser visible.
class HistorialViewModel extends ChangeNotifier {
  HistorialViewModel(this._pedidos, this._conductores, this._tab) {
    _tab.addListener(_onTabActiva);
  }

  final PedidoRepository _pedidos;
  final ConductorRepository _conductores;
  final TabActiva _tab;

  bool cargando = true;
  String? error;

  /// Pedidos entregados agrupados por día (más reciente primero).
  List<GrupoDia> grupos = const [];

  /// Ganancia por día de la semana (índice 0 = lunes .. 6 = domingo).
  List<double> ingresosSemana = List.filled(7, 0);
  double totalSemana = 0;
  int totalPedidos = 0;

  Conductor? get conductor => _conductores.conductor;
  double? get calificacion => conductor?.calificacion;
  double? get tasaAceptacion => conductor?.tasaAceptacion;

  /// Refresco silencioso al volver a este tab (cifras/estrellas al día tras
  /// entregar un pedido, sin parpadear el spinner).
  void _onTabActiva() {
    if (_tab.indice == TabActiva.historial) _cargar(silencioso: true);
  }

  Future<void> cargar() => _cargar();

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      cargando = true;
      error = null;
      notifyListeners();
    }
    await _conductores.cargar(forzar: silencioso);
    final res = await _pedidos.mios();
    res.when(
      ok: (lista) {
        final entregados =
            lista.where((p) => p.estado == EstadoPedido.entregado).toList()
              ..sort((a, b) => (b.entregadoEn ?? b.creadoEn ?? DateTime(0))
                  .compareTo(a.entregadoEn ?? a.creadoEn ?? DateTime(0)));
        totalPedidos = entregados.length;
        grupos = _agruparPorDia(entregados.take(30).toList());
        _calcularSemana(entregados);
      },
      err: (f) => error = f.message,
    );
    cargando = false;
    notifyListeners();
  }

  /// Agrupa por día calendario (los pedidos ya vienen ordenados desc).
  List<GrupoDia> _agruparPorDia(List<Pedido> entregados) {
    final resultado = <GrupoDia>[];
    DateTime? diaActual;
    var pedidosDia = <Pedido>[];
    var totalDia = 0.0;

    void cerrarGrupo() {
      if (diaActual == null || pedidosDia.isEmpty) return;
      resultado.add(GrupoDia(
        etiqueta: Formato.dia(diaActual),
        total: totalDia,
        pedidos: pedidosDia,
      ));
    }

    for (final p in entregados) {
      final f = (p.entregadoEn ?? p.creadoEn)?.toLocal();
      if (f == null) continue;
      final dia = DateTime(f.year, f.month, f.day);
      if (diaActual != dia) {
        cerrarGrupo();
        diaActual = dia;
        pedidosDia = <Pedido>[];
        totalDia = 0;
      }
      pedidosDia.add(p);
      totalDia += Pedido.gananciaNeta(p.tarifaFinal ?? p.tarifaSugerida ?? 0);
    }
    cerrarGrupo();
    return resultado;
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

  @override
  void dispose() {
    _tab.removeListener(_onTabActiva);
    super.dispose();
  }
}

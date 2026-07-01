import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../data/services/location_reporter.dart';
import '../../../data/services/location_service.dart';
import '../../../domain/models/conductor.dart';
import '../../../domain/models/estado_pedido.dart';
import '../../../domain/models/pedido.dart';

/// Estado del Inicio del conductor: disponibilidad, métricas del día, ubicación
/// y reporte de posición mientras está en línea.
class InicioViewModel extends ChangeNotifier {
  InicioViewModel(this._conductores, this._pedidos, this._location, this._usuarios)
      : _reporter = LocationReporter();

  final ConductorRepository _conductores;
  final PedidoRepository _pedidos;
  final LocationService _location;
  final UsuarioRepository _usuarios;
  final LocationReporter _reporter;

  bool cargando = true;
  bool cambiandoEstado = false;
  String? error;

  String? nombre;
  String iniciales = 'C';

  LatLng? ubicacion;
  bool permisoUbicacionDenegado = false;

  double gananciasHoy = 0;
  int pedidosHoy = 0;
  DateTime? _enLineaDesde;

  /// Oferta de pedido cercano detectada por sondeo (fallback sin push FCM).
  Pedido? ofertaActual;
  Timer? _pollOfertas;

  /// Cada cuánto se sondean ofertas mientras el conductor está en línea.
  static const Duration _intervaloOfertas = Duration(seconds: 10);

  Conductor? get conductor => _conductores.conductor;
  bool get enLinea => _conductores.enLinea;
  bool get bloqueadoPorDeuda => _conductores.bloqueadoPorDeuda;
  double? get calificacion => conductor?.calificacion;
  double? get tasaAceptacion => conductor?.tasaAceptacion;

  /// Minutos en línea en esta sesión (best-effort local; el backend no expone
  /// el acumulado del día en el MVP).
  int get minutosEnLinea {
    if (_enLineaDesde == null) return 0;
    return DateTime.now().difference(_enLineaDesde!).inMinutes;
  }

  Future<void> cargar() async {
    cargando = true;
    notifyListeners();
    await _conductores.cargar(forzar: true);
    if (enLinea) _enLineaDesde ??= DateTime.now();
    await Future.wait([_resolverUbicacion(), _cargarMetricas(), _cargarUsuario()]);
    if (enLinea) {
      _iniciarReporte();
      _iniciarPollOfertas();
    }
    cargando = false;
    notifyListeners();
  }

  Future<void> _resolverUbicacion() async {
    final res = await _location.obtenerUbicacion();
    if (res.isOk) {
      ubicacion = res.position;
      permisoUbicacionDenegado = false;
    } else {
      ubicacion = LocationService.fallbackCenter;
      permisoUbicacionDenegado = res.outcome == LocationOutcome.denied ||
          res.outcome == LocationOutcome.deniedForever;
    }
  }

  Future<void> _cargarUsuario() async {
    final res = await _usuarios.perfil();
    final u = res.valueOrNull;
    if (u != null) {
      nombre = u.primerNombre;
      iniciales = u.iniciales;
    }
  }

  Future<void> _cargarMetricas() async {
    final res = await _pedidos.mios();
    final lista = res.valueOrNull ?? const <Pedido>[];
    final hoy = DateTime.now();
    var suma = 0.0;
    var cuenta = 0;
    for (final p in lista) {
      if (p.estado != EstadoPedido.entregado) continue;
      final f = p.entregadoEn?.toLocal();
      if (f == null || f.year != hoy.year || f.month != hoy.month || f.day != hoy.day) {
        continue;
      }
      cuenta++;
      suma += Pedido.gananciaNeta(p.tarifaFinal ?? p.tarifaSugerida ?? 0);
    }
    gananciasHoy = suma;
    pedidosHoy = cuenta;
  }

  /// Alterna el estado en línea. Devuelve false si está bloqueado por deuda.
  Future<bool> alternarEnLinea(bool valor) async {
    if (valor && bloqueadoPorDeuda) return false;
    cambiandoEstado = true;
    notifyListeners();
    final res = await _conductores.cambiarEnLinea(valor, ubicacion: ubicacion);
    cambiandoEstado = false;
    final ok = res.isSuccess;
    if (ok) {
      if (valor) {
        _enLineaDesde = DateTime.now();
        _iniciarReporte();
        _iniciarPollOfertas();
      } else {
        _enLineaDesde = null;
        _reporter.stop();
        _detenerPollOfertas();
      }
    } else {
      error = res.when(ok: (_) => null, err: (f) => f.message);
    }
    notifyListeners();
    return ok;
  }

  void _iniciarReporte() {
    _reporter.start((punto) {
      ubicacion = punto;
      _conductores.reportarUbicacion(punto);
      notifyListeners();
    });
  }

  void _iniciarPollOfertas() {
    _pollOfertas?.cancel();
    _sondearOfertas(); // primer sondeo inmediato
    _pollOfertas = Timer.periodic(_intervaloOfertas, (_) => _sondearOfertas());
  }

  Future<void> _sondearOfertas() async {
    if (!enLinea || bloqueadoPorDeuda) return;
    final res = await _pedidos.ofertas();
    final lista = res.valueOrNull;
    if (lista == null) return;
    final nueva = lista.isEmpty ? null : lista.first;
    // Solo notifica si cambió (evita rebuilds/avisos repetidos por el mismo pedido).
    if (nueva?.id != ofertaActual?.id) {
      ofertaActual = nueva;
      notifyListeners();
    }
  }

  void _detenerPollOfertas() {
    _pollOfertas?.cancel();
    _pollOfertas = null;
    ofertaActual = null;
  }

  /// Descarta la oferta mostrada (p. ej. tras abrirla) sin detener el sondeo.
  void descartarOferta() {
    ofertaActual = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _reporter.stop();
    _pollOfertas?.cancel();
    super.dispose();
  }
}

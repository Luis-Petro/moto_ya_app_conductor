import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/municipio_repository.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../data/services/location_reporter.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/ofertas_service.dart';
import '../../../domain/models/conductor.dart';
import '../../../domain/models/estado_pedido.dart';
import '../../../domain/models/pedido.dart';

/// Estado del Inicio del conductor: disponibilidad, métricas del día, ubicación,
/// reporte de posición en línea, sondeo de ofertas y visibilidad del pedido
/// activo en curso.
class InicioViewModel extends ChangeNotifier {
  InicioViewModel(this._conductores, this._pedidos, this._location, this._usuarios, this._ofertas,
      this._municipios)
      : _reporter = LocationReporter();

  final ConductorRepository _conductores;
  final PedidoRepository _pedidos;
  final LocationService _location;
  final UsuarioRepository _usuarios;
  final OfertasService _ofertas;
  final MunicipioRepository _municipios;
  final LocationReporter _reporter;

  bool cargando = true;
  bool cambiandoEstado = false;
  String? error;

  String? nombre;
  String iniciales = 'C';

  /// Nombre del municipio del conductor (para el encabezado).
  String? municipioNombre;

  LatLng? ubicacion;
  bool permisoUbicacionDenegado = false;

  double gananciasHoy = 0;
  int pedidosHoy = 0;
  DateTime? _enLineaDesde;

  /// Oferta de pedido cercano detectada por sondeo (fallback sin push FCM).
  Pedido? ofertaActual;

  /// Pedido en curso asignado al conductor (ACEPTADO/EN_COMPRA/EN_CAMINO): se
  /// muestra siempre para que pueda continuar el flujo aunque no llegue push.
  Pedido? pedidoActivo;

  Timer? _poll;
  StreamSubscription<int>? _ofertaSub;
  bool _pollLento = false;

  /// Sondeo de respaldo cuando el canal STOMP de ofertas está caído: intervalo
  /// corto para no perder ofertas.
  static const Duration _pollSinStomp = Duration(seconds: 10);

  /// Sondeo relajado cuando STOMP está vivo (llega la oferta en ~0s por STOMP;
  /// esto es solo una red de seguridad).
  static const Duration _pollConStomp = Duration(seconds: 30);

  Conductor? get conductor => _conductores.conductor;
  String? get fotoUrl => conductor?.fotoUrl;
  bool get enLinea => _conductores.enLinea;
  bool get bloqueadoPorDeuda => _conductores.bloqueadoPorDeuda;

  /// Estado de verificación: la cuenta solo opera cuando está habilitada (ACTIVO).
  bool get enRevision => conductor?.enRevision ?? false;
  bool get rechazado => conductor?.rechazado ?? false;
  bool get habilitado => conductor?.habilitado ?? false;
  String? get motivoRechazo => conductor?.motivoRechazo;
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
    pedidoActivo = await _pedidos.pedidoActivo();
    if (enLinea) _reporter.start(_onPosicion);
    // Canal STOMP personal de ofertas (tiempo real, sin depender de FCM).
    _ofertaSub ??= _ofertas.connect().listen(_onOfertaStomp);
    _iniciarPoll();
    cargando = false;
    notifyListeners();
  }

  /// Oferta recibida por STOMP: revalida de inmediato contra `/pedidos/ofertas`
  /// (para descartar ofertas ya tomadas y aplicar el filtro de cercanía) en vez
  /// de confiar a ciegas en el id empujado.
  void _onOfertaStomp(int pedidoId) {
    if (enLinea && !bloqueadoPorDeuda) _tick();
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
    // Municipio del conductor (o el único disponible, persistiéndolo de una).
    final lista = (await _municipios.disponibles()).valueOrNull ?? const [];
    var municipio = _municipios.porId(u?.municipioId);
    if (municipio == null && lista.isNotEmpty) {
      municipio = lista.first;
      if (u != null && lista.length == 1) {
        await _usuarios.actualizar(municipioId: municipio.id);
      }
    }
    municipioNombre = municipio?.nombre;
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

  /// Alterna el estado en línea. Devuelve false si está bloqueado por deuda o si
  /// la cuenta aún no está habilitada por el admin.
  Future<bool> alternarEnLinea(bool valor) async {
    if (valor && (bloqueadoPorDeuda || !habilitado)) return false;
    cambiandoEstado = true;
    notifyListeners();
    final res = await _conductores.cambiarEnLinea(valor, ubicacion: ubicacion);
    cambiandoEstado = false;
    final ok = res.isSuccess;
    if (ok) {
      if (valor) {
        _enLineaDesde = DateTime.now();
        _reporter.start(_onPosicion);
      } else {
        _enLineaDesde = null;
        _reporter.stop();
        ofertaActual = null; // fuera de línea no se ofrecen pedidos
      }
    } else {
      error = res.when(ok: (_) => null, err: (f) => f.message);
    }
    notifyListeners();
    return ok;
  }

  void _onPosicion(LatLng punto) {
    ubicacion = punto;
    _conductores.reportarUbicacion(punto);
    notifyListeners();
  }

  void _iniciarPoll() {
    _poll?.cancel();
    _pollLento = _ofertas.conectado;
    _tick();
    _poll = Timer.periodic(_pollLento ? _pollConStomp : _pollSinStomp, (_) => _tick());
  }

  /// Un tick del sondeo: refresca el pedido activo SIEMPRE (para dar visibilidad
  /// del pedido en curso) y las ofertas solo si está en línea y sin bloqueo.
  Future<void> _tick() async {
    final activo = await _pedidos.pedidoActivo();
    if (activo?.id != pedidoActivo?.id) {
      pedidoActivo = activo;
      notifyListeners();
    }
    if (enLinea && !bloqueadoPorDeuda) {
      final res = await _pedidos.ofertas();
      final lista = res.valueOrNull;
      if (lista != null) {
        final nueva = lista.isEmpty ? null : lista.first;
        if (nueva?.id != ofertaActual?.id) {
          ofertaActual = nueva;
          notifyListeners();
        }
      }
    } else if (ofertaActual != null) {
      ofertaActual = null;
      notifyListeners();
    }
    // Ajusta el ritmo del sondeo si el canal STOMP cambió de estado (subió/cayó).
    if (_pollLento != _ofertas.conectado) _iniciarPoll();
  }

  /// Fuerza un refresco (p. ej. al volver de la pantalla del pedido activo).
  Future<void> refrescar() async {
    await _conductores.cargar(forzar: true);
    await _cargarMetricas();
    await _tick();
  }

  /// Descarta la oferta mostrada (p. ej. tras abrirla) sin detener el sondeo.
  void descartarOferta() {
    ofertaActual = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _reporter.stop();
    _poll?.cancel();
    _ofertaSub?.cancel();
    _ofertas.disconnect();
    super.dispose();
  }
}

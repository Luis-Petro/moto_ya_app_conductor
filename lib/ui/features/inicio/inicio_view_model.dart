import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/municipio_repository.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../data/services/location_reporter.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/notificacion_local_service.dart';
import '../../../data/services/ofertas_service.dart';
import '../../../data/services/permisos_service.dart';
import '../../../domain/models/conductor.dart';
import '../../../domain/models/demanda_zonas.dart';
import '../../../domain/models/estado_pedido.dart';
import '../../../domain/models/oferta.dart';
import '../../../domain/models/pedido.dart';
import '../../core/tab_activa.dart';

/// Desenlace de intentar ponerse en línea. La UI mapea cada caso a su aviso:
/// los `falta*` ofrecen abrir Ajustes; el resto ya se refleja en el estado.
enum ResultadoEnLinea {
  ok,
  bloqueadoDeuda,
  noHabilitado,
  faltaUbicacionServicio,
  faltaUbicacionPermiso,
  faltaNotificaciones,

  /// Sin foto de perfil. El cliente elige a quién le abre la puerta viendo la
  /// cara del conductor; una silueta gris no es una identidad.
  faltaFotoPerfil,
  error,
}

/// Estado del Inicio del conductor: disponibilidad, métricas del día, ubicación,
/// reporte de posición en línea, sondeo de ofertas y visibilidad del pedido
/// activo en curso.
class InicioViewModel extends ChangeNotifier {
  InicioViewModel(
    this._conductores,
    this._pedidos,
    this._location,
    this._usuarios,
    this._ofertas,
    this._municipios,
    this._permisos,
    this._avisos,
    this._tab,
  ) : _reporter = LocationReporter() {
    _tab.addListener(_onTabActiva);
  }

  final ConductorRepository _conductores;
  final PedidoRepository _pedidos;
  final LocationService _location;
  final UsuarioRepository _usuarios;
  final OfertasService _ofertas;
  final MunicipioRepository _municipios;
  final PermisosService _permisos;
  final NotificacionLocalService _avisos;
  final TabActiva _tab;
  final LocationReporter _reporter;

  /// Refresco silencioso al volver a este tab (cifras del día al día).
  void _onTabActiva() {
    if (_tab.indice == TabActiva.inicio) refrescar();
  }

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

  /// Oferta dirigida vigente para el conductor (con la ventana del servidor).
  Oferta? ofertaActual;

  /// Pedido en curso asignado al conductor (ACEPTADO/EN_COMPRA/EN_CAMINO): se
  /// muestra siempre para que pueda continuar el flujo aunque no llegue push.
  Pedido? pedidoActivo;

  /// Demanda reciente por zonas (la calcula el backend). Null mientras carga o
  /// si la consulta falló; con `celdas` vacía significa "no hay datos", que es
  /// un resultado legítimo y se muestra como tal.
  DemandaZonas? demanda;
  bool cargandoDemanda = false;

  /// Exención de la optimización de batería. Sin ella el sistema mata el proceso
  /// al minimizar la app en los teléfonos de gama media, y no llegan ni el push
  /// ni el sondeo. Es informativa: nunca impide ponerse en línea.
  PermisoBateria bateria = PermisoBateria.noAplica;

  /// El conductor está en línea pero el backend ya no lo ve, porque lleva más del
  /// margen sin conseguir reportar su posición. Sin este aviso creería que está
  /// disponible mientras el matching lo descartó, y no tendría forma de saber por
  /// qué dejaron de llegarle ofertas.
  bool get sinVisibilidad => enLinea && _reporter.reporteCaducado;

  /// Vigila el margen de visibilidad. El reporte falla en silencio —ni el GPS ni
  /// la red avisan— así que el aviso solo puede aparecer mirando el reloj.
  Timer? _vigilanciaVisibilidad;
  static const Duration _cadenciaVigilancia = Duration(seconds: 30);

  Timer? _poll;
  StreamSubscription<EventoOferta>? _ofertaSub;
  bool _pollLento = false;
  bool _disposed = false;

  /// Sondeo de respaldo cuando el canal STOMP de ofertas está caído: intervalo
  /// corto para no perder ofertas.
  static const Duration _pollSinStomp = Duration(seconds: 10);

  /// Sondeo relajado cuando STOMP está vivo (llega la oferta en ~0s por STOMP;
  /// esto es solo una red de seguridad).
  static const Duration _pollConStomp = Duration(seconds: 30);

  Conductor? get conductor => _conductores.conductor;
  String? get fotoUrl => conductor?.fotoUrl;

  /// Tiene foto de perfil. Es requisito para ponerse en línea: el cliente ve la
  /// cara del conductor en la tarjeta de propuesta antes de aceptarla.
  bool get tieneFotoPerfil => (fotoUrl ?? '').trim().isNotEmpty;

  /// Subiendo la foto de perfil desde el aviso del Inicio.
  bool subiendoFoto = false;
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
    // El nombre y las iniciales que ya trajo el splash se siembran **antes** del
    // primer notifyListeners: así el esqueleto de carga puede pintar el avatar y
    // el nombre de verdad en el primer frame, en vez de dos siluetas grises. No
    // cuesta una petición y es lo que hace que la pantalla se reconozca mientras
    // llega el resto.
    _sembrarIdentidadDeCache();
    notifyListeners();
    // Solo el perfil de conductor bloquea el primer render (gatea alta/estado);
    // usa la caché si el splash ya lo trajo. Todo lo demás llega en segundo
    // plano y va notificando: el home aparece de inmediato.
    await _conductores.cargar(forzar: _conductores.conductor == null);
    if (enLinea) _enLineaDesde ??= DateTime.now();
    cargando = false;
    notifyListeners();

    unawaited(_resolverUbicacion().then((_) => _notificar()));
    unawaited(_cargarMetricas().then((_) => _notificar()));
    unawaited(_cargarUsuario().then((_) => _notificar()));
    unawaited(
      _pedidos.pedidoActivo().then((p) {
        pedidoActivo = p;
        _notificar();
      }),
    );
    unawaited(cargarDemanda());
    unawaited(
      _permisos.estadoBateria().then((b) {
        bateria = b;
        _notificar();
      }),
    );
    if (enLinea) _arrancarReporte();
    // Canal STOMP personal de ofertas (tiempo real, sin depender de FCM).
    _ofertaSub ??= _ofertas.connect().listen(_onEventoOferta);
    _iniciarPoll();
  }

  /// notifyListeners seguro para callbacks en segundo plano que pueden llegar
  /// después de que la pantalla se destruya.
  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  /// Evento de oferta por STOMP. `PEDIDO_NUEVO` revalida contra `/pedidos/ofertas`
  /// (para descartar ofertas ya tomadas) en vez de confiar a ciegas en el id.
  /// Los eventos de cierre (`OFERTA_EXPIRADA`/`PEDIDO_TOMADO`/`PEDIDO_CANCELADO`)
  /// retiran de inmediato la oferta mostrada si corresponde a ese pedido.
  void _onEventoOferta(EventoOferta e) {
    if (e.tipo.cierraOferta) {
      // Retira también el aviso del sistema, lo estuviera mostrando esta pantalla
      // o no: pudo pintarlo el handler de background con la app cerrada, y un
      // aviso que sigue ofreciendo un pedido muerto es peor que ninguno.
      unawaited(_avisos.retirarOferta(e.pedidoId));
      if (ofertaActual?.pedidoId == e.pedidoId) {
        ofertaActual = null;
        _notificar();
      }
      return;
    }
    if (enLinea && !bloqueadoPorDeuda) _tick();
  }

  Future<void> _resolverUbicacion() async {
    final res = await _location.obtenerUbicacion();
    if (res.isOk) {
      ubicacion = res.position;
      permisoUbicacionDenegado = false;
    } else {
      ubicacion = LocationService.fallbackCenter;
      permisoUbicacionDenegado =
          res.outcome == LocationOutcome.denied ||
          res.outcome == LocationOutcome.deniedForever;
    }
  }

  /// Nombre e iniciales del usuario ya guardado en la sesión, si los hay.
  void _sembrarIdentidadDeCache() {
    final u = _usuarios.enCache;
    if (u == null) return;
    nombre ??= u.primerNombre;
    iniciales = u.iniciales;
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
      if (f == null ||
          f.year != hoy.year ||
          f.month != hoy.month ||
          f.day != hoy.day) {
        continue;
      }
      cuenta++;
      suma += Pedido.gananciaNeta(p.tarifaFinal ?? p.tarifaSugerida ?? 0);
    }
    gananciasHoy = suma;
    pedidosHoy = cuenta;
  }

  /// ¿Hay que explicarle el uso de la ubicación antes de pedirle el permiso?
  ///
  /// Las tiendas exigen que la explicación de qué se comparte, cuándo y para qué
  /// aparezca **antes** del diálogo del sistema, y no vale ponerla solo en la ficha
  /// de la tienda. Devuelve `true` cuando el permiso todavía no está concedido.
  Future<bool> necesitaExplicarUbicacion() async =>
      !await _permisos.ubicacionYaConcedida();

  /// Alterna el estado en línea. Ponerse en línea EXIGE ubicación y
  /// notificaciones activas (se solicitan si faltan); apagarse nunca las exige.
  /// Devuelve el desenlace para que la UI muestre el aviso correspondiente.
  Future<ResultadoEnLinea> alternarEnLinea(bool valor) async {
    if (!valor) {
      return await _aplicarEnLinea(false)
          ? ResultadoEnLinea.ok
          : ResultadoEnLinea.error;
    }
    if (bloqueadoPorDeuda) return ResultadoEnLinea.bloqueadoDeuda;
    if (!habilitado) return ResultadoEnLinea.noHabilitado;
    if (!tieneFotoPerfil) return ResultadoEnLinea.faltaFotoPerfil;

    // Permisos obligatorios para recibir pedidos.
    final permisos = await _permisos.asegurarParaOperar();
    switch (permisos.ubicacion) {
      case PermisoUbicacion.servicioApagado:
        return ResultadoEnLinea.faltaUbicacionServicio;
      case PermisoUbicacion.denegado:
      case PermisoUbicacion.denegadoPermanente:
        return ResultadoEnLinea.faltaUbicacionPermiso;
      case PermisoUbicacion.ok:
        break;
    }
    if (permisos.notificaciones != PermisoNotificaciones.ok) {
      return ResultadoEnLinea.faltaNotificaciones;
    }
    // La exención de batería NO bloquea. El sistema puede ni ofrecer el diálogo,
    // y dejar a un conductor sin poder trabajar por una pantalla que su teléfono
    // no muestra es peor que el problema. Se registra y la pantalla lo deja
    // visible: puede perder avisos con la app cerrada.
    bateria = permisos.bateria;

    // Con permiso recién concedido, refresca la ubicación real antes de
    // publicar el estado (así no arrancamos en el fallback del municipio).
    await _resolverUbicacion();
    return await _aplicarEnLinea(true)
        ? ResultadoEnLinea.ok
        : ResultadoEnLinea.error;
  }

  Future<bool> _aplicarEnLinea(bool valor) async {
    cambiandoEstado = true;
    notifyListeners();
    final res = await _conductores.cambiarEnLinea(valor, ubicacion: ubicacion);
    cambiandoEstado = false;
    final ok = res.isSuccess;
    if (ok) {
      if (valor) {
        _enLineaDesde = DateTime.now();
        _arrancarReporte();
      } else {
        _enLineaDesde = null;
        // Detiene el reporte y con él la notificación del servicio en primer
        // plano: fuera de línea no se comparte ubicación, y dejar el indicador
        // permanente diciendo lo contrario sería mentirle al conductor.
        _detenerReporte();
        // Fuera de línea no se ofrecen pedidos: se retira la oferta de la
        // pantalla y también su aviso del sistema, si quedó uno abierto.
        final pedidoId = ofertaActual?.pedidoId;
        ofertaActual = null;
        if (pedidoId != null) unawaited(_avisos.retirarOferta(pedidoId));
      }
    } else {
      error = res.when(ok: (_) => null, err: (f) => f.message);
    }
    notifyListeners();
    return ok;
  }

  /// Toma o elige la foto de perfil y la sube, sin salir del Inicio: mandar al
  /// conductor a otra pestaña a buscarla era la forma segura de que no la
  /// pusiera nunca. Devuelve el mensaje de error, o null si salió bien o si
  /// canceló la selección.
  Future<String?> subirFotoPerfil(ImageSource source) async {
    final XFile? img = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
      preferredCameraDevice: CameraDevice.front,
    );
    if (img == null) return null;
    subiendoFoto = true;
    _notificar();
    final mp = await MultipartFile.fromFile(img.path, filename: img.name);
    final res = await _conductores.subirFoto(mp);
    subiendoFoto = false;
    final err = res.when(ok: (_) => null, err: (f) => f.message);
    _notificar();
    return err;
  }

  /// Ofrece el diálogo del sistema para salir de la optimización de batería.
  /// Se respeta el rechazo: solo se refresca el estado que pinta el aviso.
  Future<void> pedirExencionBateria() async {
    bateria = await _permisos.pedirExencionBateria();
    _notificar();
  }

  /// Abre los Ajustes de la app (permiso de ubicación/notificaciones denegado).
  Future<void> abrirConfiguracionApp() => _permisos.abrirConfiguracionApp();

  /// Abre los Ajustes de ubicación del sistema (GPS apagado).
  Future<void> abrirConfiguracionUbicacion() =>
      _permisos.abrirConfiguracionUbicacion();

  Future<void> _onPosicion(LatLng punto) async {
    ubicacion = punto;
    _notificar();
    // El sello de visibilidad se pone con el desenlace del envío, no con el fix
    // del GPS: si el POST falla, la posición no llega al backend y el conductor
    // deja de ser visible exactamente igual que si no tuviera señal.
    final res = await _conductores.reportarUbicacion(punto);
    if (res.isSuccess) _reporter.marcarReporteOk();
    _notificar();
  }

  /// Arranca el reporte de posición y su vigilancia.
  void _arrancarReporte() {
    _reporter.start(_onPosicion, background: true, inicial: ubicacion);
    _vigilanciaVisibilidad?.cancel();
    _vigilanciaVisibilidad = Timer.periodic(
      _cadenciaVigilancia,
      (_) => _notificar(),
    );
  }

  void _detenerReporte() {
    _reporter.stop();
    _vigilanciaVisibilidad?.cancel();
    _vigilanciaVisibilidad = null;
  }

  /// El sistema puede matar el servicio en primer plano con la app minimizada —
  /// es justo lo que hacen los teléfonos sin la exención de batería. Al volver a
  /// la app se comprueba y se restablece: un conductor en línea sin reporte no
  /// recibe ofertas y nada se lo dice.
  Future<void> alVolverDeSegundoPlano() async {
    bateria = await _permisos.estadoBateria();
    if (enLinea && !_reporter.activo) _arrancarReporte();
    _notificar();
  }

  void _iniciarPoll() {
    _poll?.cancel();
    _pollLento = _ofertas.conectado;
    _tick();
    _poll = Timer.periodic(
      _pollLento ? _pollConStomp : _pollSinStomp,
      (_) => _tick(),
    );
  }

  /// Un tick del sondeo: refresca el pedido activo SIEMPRE (para dar visibilidad
  /// del pedido en curso) y las ofertas solo si está en línea y sin bloqueo.
  Future<void> _tick() async {
    final activo = await _pedidos.pedidoActivo();
    if (activo?.id != pedidoActivo?.id) {
      pedidoActivo = activo;
      _notificar();
    }
    if (enLinea && !bloqueadoPorDeuda) {
      final res = await _pedidos.ofertas();
      final lista = res.valueOrNull;
      if (lista != null) {
        final nueva = lista.isEmpty ? null : lista.first;
        if (nueva?.pedidoId != ofertaActual?.pedidoId) {
          ofertaActual = nueva;
          _notificar();
        }
      }
    } else if (ofertaActual != null) {
      ofertaActual = null;
      _notificar();
    }
    // Ajusta el ritmo del sondeo si el canal STOMP cambió de estado (subió/cayó).
    if (_pollLento != _ofertas.conectado) _iniciarPoll();
  }

  /// Trae la demanda por zonas del backend. Un fallo deja `demanda` en null y
  /// la UI lo trata como "no disponible": nunca se rellena con datos propios.
  Future<void> cargarDemanda() async {
    cargandoDemanda = true;
    _notificar();
    final res = await _conductores.demanda();
    demanda = res.valueOrNull;
    cargandoDemanda = false;
    _notificar();
  }

  /// Fuerza un refresco (al volver de la pantalla del pedido activo, con el
  /// gesto de arrastrar hacia abajo o al reactivarse el tab). Silencioso: no
  /// enciende el spinner de pantalla completa.
  Future<void> refrescar() async {
    await _conductores.cargar(forzar: true);
    await _cargarMetricas();
    await _tick();
    await cargarDemanda();
    _notificar();
  }

  /// Descarta la oferta mostrada (p. ej. tras abrirla) sin detener el sondeo.
  void descartarOferta() {
    ofertaActual = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tab.removeListener(_onTabActiva);
    _detenerReporte();
    _poll?.cancel();
    _ofertaSub?.cancel();
    _ofertas.disconnect();
    super.dispose();
  }
}

import 'dart:async';

import '../../domain/models/usuario.dart';
import '../services/api_result.dart';
import '../services/usuario_service.dart';

/// Fuente de verdad del perfil del usuario, con caché en memoria.
class UsuarioRepository {
  UsuarioRepository(this._service);

  final UsuarioService _service;
  Usuario? _cache;

  Usuario? get enCache => _cache;

  Future<Result<Usuario>> perfil({bool forzar = false}) async {
    if (_cache != null && !forzar) return Ok(_cache!);
    final res = await _service.obtenerPerfil();
    if (res case Ok<Usuario>(value: final u)) {
      _cache = u;
    }
    return res;
  }

  // ────────────────────────── Municipio del usuario ─────────────────────────

  /// Cuánto se insiste, como mucho, antes de rendirse.
  ///
  /// **Es un presupuesto de reloj, no un número de intentos**, y esa distinción
  /// es el arreglo. Un límite en intentos no acota nada mientras cada intento
  /// pueda durar lo que le permita el cliente HTTP: con `connectTimeout` de 12 s
  /// y `receiveTimeout` de 20 s, seis intentos escalonados son hasta tres
  /// minutos, y durante todos ellos el mapa enseña un esqueleto que no termina.
  static const presupuestoMunicipio = Duration(seconds: 20);

  /// Esperas entre intentos, escalonadas. Acotadas además por el presupuesto.
  static const _esperasMunicipio = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 4),
    Duration(seconds: 5),
  ];

  Future<int?>? _resolviendoMunicipio;

  /// El municipio del usuario, **pidiéndolo** si hace falta. `null` si no se
  /// pudo dentro del presupuesto.
  ///
  /// Existe porque la capa de lugares de los mapas se limitaba a mirar [enCache]
  /// a ver si alguien la había llenado. En esta app el perfil lo pide el Inicio
  /// con `unawaited`, así que eso convertía los marcadores en una carrera contra
  /// esa petición: salían si ganaba ella y no salían nunca si el mapa se montaba
  /// primero — ni siquiera al reintentar a mano, porque el reintento releía la
  /// misma caché vacía.
  ///
  /// Las llamadas concurrentes comparten un mismo intento: al abrir la app, el
  /// mapa del Inicio y el del pedido activo arrancan casi a la vez. Al terminar
  /// se suelta, así que un intento agotado **no** deja la app inservible: el
  /// siguiente que pregunte vuelve a intentarlo de verdad.
  Future<int?> resolverMunicipio({
    Duration presupuesto = presupuestoMunicipio,
  }) {
    final yaLoTengo = _cache?.municipioId;
    if (yaLoTengo != null) return Future.value(yaLoTengo);
    // Cuerpo de bloque, no flecha: `=> _resolviendoMunicipio = null` devuelve
    // `null` y es inofensivo, pero la misma forma con un `Map.remove` detrás es
    // la que dejó a `LugarService` sin completar nunca. La regla del proyecto es
    // que un callback de `whenComplete` no devuelve nada por accidente.
    return _resolviendoMunicipio ??= _resolverMunicipio(presupuesto)
        .whenComplete(() {
      _resolviendoMunicipio = null;
    });
  }

  Future<int?> _resolverMunicipio(Duration presupuesto) async {
    final reloj = Stopwatch()..start();
    for (var intento = 0;; intento++) {
      final restante = presupuesto - reloj.elapsed;
      if (restante <= Duration.zero) return null;
      // El `timeout` es lo que hace que el presupuesto se cumpla de verdad: sin
      // él, una petición que no vuelve se lleva por delante el plazo entero y
      // deja al llamante esperando sin nada que enseñar. La petición que se
      // abandona sigue su curso y, si llega, llena la caché para el siguiente.
      Result<Usuario>? res;
      try {
        res = await perfil(forzar: intento > 0).timeout(restante);
      } on TimeoutException {
        return null;
      }
      final id = res.valueOrNull?.municipioId;
      if (id != null) return id;
      if (intento >= _esperasMunicipio.length) return null;
      final espera = _esperasMunicipio[intento];
      final margen = presupuesto - reloj.elapsed;
      if (margen <= Duration.zero) return null;
      await Future<void>.delayed(espera < margen ? espera : margen);
    }
  }

  Future<Result<Usuario>> actualizar({
    String? nombre,
    int? municipioId,
  }) async {
    final res = await _service.actualizarPerfil(
        nombre: nombre, municipioId: municipioId);
    if (res case Ok<Usuario>(value: final u)) {
      _cache = u;
    }
    return res;
  }

  /// Paso 1 del cambio de correo: envía un código al correo nuevo.
  Future<Result<void>> solicitarCambioEmail(String email) =>
      _service.solicitarCambioEmail(email);

  /// Paso 2: confirma el código; al aceptar, refresca la caché con el correo nuevo.
  Future<Result<Usuario>> verificarCambioEmail(String codigo) async {
    final res = await _service.verificarCambioEmail(codigo);
    if (res case Ok<Usuario>(value: final u)) {
      _cache = u;
    }
    return res;
  }

  /// Paso 1 del cambio de celular: envía un OTP al número nuevo.
  Future<Result<void>> solicitarCambioTelefono(String telefono) =>
      _service.solicitarCambioTelefono(telefono);

  /// Paso 2: confirma el código; al aceptar, refresca la caché con el número
  /// nuevo ya verificado.
  Future<Result<Usuario>> verificarCambioTelefono(String codigo) async {
    final res = await _service.verificarCambioTelefono(codigo);
    if (res case Ok<Usuario>(value: final u)) {
      _cache = u;
    }
    return res;
  }

  /// Baja de la cuenta. Al aceptar limpia la caché: el perfil que quedaba en
  /// memoria ya no corresponde a ninguna cuenta viva.
  Future<Result<void>> eliminarCuenta() async {
    final res = await _service.eliminarCuenta();
    if (res.isSuccess) limpiar();
    return res;
  }

  /// Verificar el celular que ya tiene la cuenta (sin cambiarlo).
  Future<Result<void>> solicitarVerificacionTelefonoActual() =>
      _service.solicitarVerificacionTelefonoActual();

  Future<Result<Usuario>> verificarTelefonoActual(String codigo) async {
    final res = await _service.verificarTelefonoActual(codigo);
    if (res case Ok<Usuario>(value: final u)) {
      _cache = u;
    }
    return res;
  }

  /// Verificar el correo que ya tiene la cuenta (sin cambiarlo).
  Future<Result<void>> solicitarVerificacionEmailActual() =>
      _service.solicitarVerificacionEmailActual();

  Future<Result<Usuario>> verificarEmailActual(String codigo) async {
    final res = await _service.verificarEmailActual(codigo);
    if (res case Ok<Usuario>(value: final u)) {
      _cache = u;
    }
    return res;
  }

  void limpiar() => _cache = null;
}

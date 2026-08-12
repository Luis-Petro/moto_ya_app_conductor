import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../domain/models/conductor.dart';
import '../../../domain/models/usuario.dart';
import '../../core/tab_activa.dart';

/// Estado del Perfil del conductor: datos personales, vehículo/documentos y
/// cierre de sesión. El nombre y el celular son la identidad verificada y no
/// se editan desde la app; solo el correo.
class PerfilViewModel extends ChangeNotifier {
  PerfilViewModel(this._usuarios, this._conductores, this._auth, this._tab) {
    _tab.addListener(_onTabActiva);
  }

  final UsuarioRepository _usuarios;
  final ConductorRepository _conductores;
  final AuthRepository _auth;
  final TabActiva _tab;

  /// Refresco silencioso al volver a este tab (estrellas/foto al día).
  void _onTabActiva() {
    if (_tab.indice == TabActiva.perfil) _cargar(silencioso: true);
  }

  bool cargando = true;
  String? error;
  Usuario? usuario;

  bool subiendoFoto = false;

  /// Estado del flujo de cambio de correo (verificado por código).
  bool enviandoCodigo = false;
  bool verificandoCodigo = false;

  /// Estado del flujo de cambio de celular (verificado por OTP).
  bool enviandoCodigoTelefono = false;
  bool verificandoCodigoTelefono = false;

  /// Documento que se está subiendo ahora mismo (para el spinner de su fila).
  DocumentoConductor? subiendoDocumento;

  Conductor? get conductor => _conductores.conductor;

  /// Elige una foto de la galería y la sube como foto de perfil del conductor.
  /// Devuelve true si se actualizó; null si el usuario canceló la selección.
  Future<bool?> cambiarFoto() async {
    final XFile? img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (img == null) return null;
    subiendoFoto = true;
    notifyListeners();
    final multipart = await MultipartFile.fromFile(img.path, filename: img.name);
    final res = await _conductores.subirFoto(multipart);
    subiendoFoto = false;
    final ok = res.isSuccess;
    if (!ok) error = res.when(ok: (_) => null, err: (f) => f.message);
    notifyListeners();
    return ok;
  }

  Future<void> cargar() => _cargar();

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      cargando = true;
      notifyListeners();
    }
    await _conductores.cargar(forzar: silencioso);
    final res = await _usuarios.perfil(forzar: true);
    res.when(ok: (u) => usuario = u, err: (f) => error = f.message);
    cargando = false;
    notifyListeners();
  }

  /// Paso 1 del cambio de correo: envía un código al correo nuevo. Devuelve el
  /// mensaje de error o null si se envió bien.
  Future<String?> solicitarCambioCorreo(String email) async {
    enviandoCodigo = true;
    notifyListeners();
    final res = await _usuarios.solicitarCambioEmail(email);
    enviandoCodigo = false;
    notifyListeners();
    return res.when(ok: (_) => null, err: (f) => f.message);
  }

  /// Paso 2: confirma el código; al aceptar, actualiza el correo mostrado.
  /// Devuelve el mensaje de error o null si se confirmó.
  Future<String?> confirmarCambioCorreo(String codigo) async {
    verificandoCodigo = true;
    notifyListeners();
    final res = await _usuarios.verificarCambioEmail(codigo);
    verificandoCodigo = false;
    final err = res.when(ok: (u) {
      usuario = u;
      return null;
    }, err: (f) => f.message);
    notifyListeners();
    return err;
  }

  // ── Cambio de celular verificado por OTP (mismo patrón que el correo) ──

  /// Paso 1: envía un código al número nuevo. Devuelve el error o null si salió.
  Future<String?> solicitarCambioCelular(String telefono) async {
    enviandoCodigoTelefono = true;
    notifyListeners();
    final res = await _usuarios.solicitarCambioTelefono(telefono);
    enviandoCodigoTelefono = false;
    notifyListeners();
    return res.when(ok: (_) => null, err: (f) => f.message);
  }

  /// Paso 2: confirma el código; al aceptar, el número queda verificado.
  Future<String?> confirmarCambioCelular(String codigo) async {
    verificandoCodigoTelefono = true;
    notifyListeners();
    final res = await _usuarios.verificarCambioTelefono(codigo);
    verificandoCodigoTelefono = false;
    final err = res.when(ok: (u) {
      usuario = u;
      return null;
    }, err: (f) => f.message);
    notifyListeners();
    return err;
  }

  // ─────────────────────────── Documentos ───────────────────────────

  /// Sube (o reemplaza) uno de los cuatro documentos de habilitación. Devuelve
  /// el mensaje de error, o null si salió bien o si el conductor canceló.
  Future<String?> subirDocumento(
      DocumentoConductor doc, ImageSource source) async {
    final XFile? img = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      preferredCameraDevice: doc == DocumentoConductor.selfie
          ? CameraDevice.front
          : CameraDevice.rear,
    );
    if (img == null) return null;
    subiendoDocumento = doc;
    notifyListeners();
    final mp = await MultipartFile.fromFile(img.path, filename: img.name);
    final res = switch (doc) {
      DocumentoConductor.cedula => await _conductores.subirCedula(mp),
      DocumentoConductor.tarjetaPropiedad =>
        await _conductores.subirPapelesMoto(mp),
      DocumentoConductor.selfie => await _conductores.subirSelfie(mp),
      DocumentoConductor.fotoMoto => await _conductores.subirFotoMoto(mp),
    };
    subiendoDocumento = null;
    final err = res.when(ok: (_) => null, err: (f) => f.message);
    notifyListeners();
    return err;
  }

  Future<void> cerrarSesion() async {
    // Deja al conductor FUERA de línea en el backend antes de borrar el JWT: si
    // no, seguiría `en_linea=1` y el dispatcher podría ofrecerle pedidos con la
    // app cerrada. Best-effort: no bloquea el logout si la red falla.
    if (_conductores.enLinea) {
      await _conductores.cambiarEnLinea(false);
    }
    await _auth.cerrarSesion();
    _conductores.limpiar();
    _usuarios.limpiar();
  }

  bool eliminandoCuenta = false;

  /// Da de baja la cuenta y cierra la sesión. Devuelve `null` si salió bien, o el
  /// motivo si el backend lo rechazó —pedido en curso o deuda pendiente—, para
  /// mostrarlo tal cual: el mensaje del servidor explica qué hacer.
  Future<String?> eliminarCuenta() async {
    eliminandoCuenta = true;
    notifyListeners();
    final res = await _usuarios.eliminarCuenta();
    final error = res.when(ok: (_) => null, err: (f) => f.message);
    if (error == null) {
      // El backend ya lo dejó fuera de línea al eliminarlo, así que aquí basta con
      // soltar la sesión y las cachés.
      await _auth.cerrarSesion();
      _conductores.limpiar();
      _usuarios.limpiar();
      return null;
    }
    eliminandoCuenta = false;
    notifyListeners();
    return error;
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabActiva);
    super.dispose();
  }
}

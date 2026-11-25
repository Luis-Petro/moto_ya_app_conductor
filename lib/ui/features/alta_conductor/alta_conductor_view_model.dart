import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/municipio_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../data/services/api_result.dart';
import '../../../data/services/borrador_alta.dart';
import '../../../data/services/imagen_compresor.dart';
import '../../../data/services/location_service.dart';
import '../../../domain/models/conductor.dart';
import '../../../domain/models/municipio.dart';
import '../../../domain/models/usuario.dart';

/// Estado del alta del perfil de conductor.
class AltaConductorViewModel extends ChangeNotifier {
  AltaConductorViewModel(
    this._conductores,
    this._location,
    this._municipios,
    this._usuarios, {
    BorradorAlta? borrador,
    ImagenCompresor compresor = const ImagenCompresor(),
  })  : _borrador = borrador ?? BorradorAlta(),
        _compresor = compresor;

  final ConductorRepository _conductores;
  final LocationService _location;
  final MunicipioRepository _municipios;
  final UsuarioRepository _usuarios;
  final BorradorAlta _borrador;
  final ImagenCompresor _compresor;

  bool cargando = true;
  bool guardando = false;
  String? error;

  /// No se pudo averiguar si el conductor ya tiene perfil. Ver [cargar].
  String? errorCarga;
  bool errorCargaEsRed = false;

  /// True cuando el backend rechazó con 403: el JWT guardado no tiene rol
  /// CONDUCTOR (sesión emitida antes de la promoción de rol). La pantalla debe
  /// cerrar sesión para forzar un login fresco.
  bool sesionInvalida = false;

  /// El perfil **ya existía cuando se abrió esta pantalla**.
  ///
  /// Es lo único que autoriza a saltar al Inicio sin pasar por el alta. Antes la
  /// pantalla miraba `perfilCompleto` en cada repintado, y ese valor pasa a
  /// `true` a mitad del envío, en cuanto el perfil se crea y antes de subir las
  /// fotos. Si la cédula fallaba ahí, el repintado del error mandaba al
  /// conductor al Inicio **y con él se iban las cuatro fotos**: quedaba con el
  /// perfil creado, ningún documento y un mensaje de "toca Enviar para
  /// reintentar" sobre una pantalla que ya no tenía ese botón.
  bool yaTeniaPerfil = false;

  // ── Fotos ──

  /// Fotos elegidas localmente; se suben tras crear el perfil (los endpoints de
  /// documentos exigen que el conductor ya exista).
  final Map<DocumentoConductor, File> _fotos = {};

  /// Las que ya llegaron al servidor en este envío: un reintento no las repite.
  final Set<DocumentoConductor> _subidas = {};

  File? get cedula => _fotos[DocumentoConductor.cedula];
  File? get papelesMoto => _fotos[DocumentoConductor.tarjetaPropiedad];
  File? get selfie => _fotos[DocumentoConductor.selfie];
  File? get fotoMoto => _fotos[DocumentoConductor.fotoMoto];

  /// Lo que el conductor lleva hecho, tal como quedó guardado en el teléfono.
  /// La pantalla lo lee una vez, al terminar de cargar, para rellenar el
  /// formulario.
  DatosBorradorAlta borrador = const DatosBorradorAlta();

  final _cargaLista = Completer<void>();

  /// Hay cédula: tomada ahora o subida en un intento anterior.
  bool get tieneCedula => _cedulaLista;

  /// Guarda la foto de un documento **y la deja en el borrador**: salir de la
  /// pantalla ya no la pierde.
  Future<void> elegirFoto(DocumentoConductor doc, File f) async {
    _fotos[doc] = f;
    _subidas.remove(doc);
    error = null;
    notifyListeners();

    final id = cuenta?.id;
    if (id == null) return;
    final copia = await _borrador.conservarFoto(id, doc, f,
        anterior: borrador.fotos[doc]);
    // Si mientras se copiaba el conductor repitió la foto, manda la nueva.
    if (_fotos[doc] != f) return;
    _fotos[doc] = copia;
    borrador = borrador.copyWith(
      fotos: {...borrador.fotos, doc: copia.path},
      limpiarCapturaPendiente: true,
    );
    await _persistir();
    notifyListeners();
  }

  /// Apunta para qué documento se va a abrir la cámara. Ver
  /// [DatosBorradorAlta.capturaPendiente].
  Future<void> anotarCaptura(DocumentoConductor doc) async {
    borrador = borrador.copyWith(capturaPendiente: doc);
    await _persistir();
  }

  /// La cámara se cerró sin foto.
  Future<void> capturaCancelada() async {
    if (borrador.capturaPendiente == null) return;
    borrador = borrador.copyWith(limpiarCapturaPendiente: true);
    await _persistir();
  }

  /// Android mató la app con la cámara abierta y ahora devuelve la foto: se le
  /// asigna al documento que se había apuntado.
  Future<void> recuperarFotoPerdida(File f) async {
    await _cargaLista.future;
    final doc = borrador.capturaPendiente;
    if (doc == null) return;
    await elegirFoto(doc, f);
  }

  /// Guarda en el borrador lo escrito en el formulario y el paso en que va.
  void recordarCampos({
    required String? marca,
    required String? modelo,
    required String marcaLibre,
    required String modeloLibre,
    required String placa,
    required String licencia,
    required int paso,
  }) {
    borrador = DatosBorradorAlta(
      marca: marca,
      modelo: modelo,
      marcaLibre: marcaLibre,
      modeloLibre: modeloLibre,
      placa: placa,
      licencia: licencia,
      paso: paso,
      fotos: borrador.fotos,
      capturaPendiente: borrador.capturaPendiente,
    );
    unawaited(_persistir());
  }

  Future<void> _persistir() async {
    final id = cuenta?.id;
    if (id == null) return;
    await _borrador.guardar(id, borrador);
  }

  /// El alta terminó: lo guardado en el teléfono ya no hace falta.
  Future<void> cerrarBorrador() async {
    final id = cuenta?.id;
    if (id != null) await _borrador.borrar(id);
  }

  /// Los cuatro documentos que el admin exige para habilitar, y cuáles faltan.
  /// Cuenta lo ya subido en el servidor además de lo elegido en esta pantalla:
  /// quien vuelve al alta tras subir la cédula no debe volver a tomarla.
  static const int documentosRequeridos = 4;

  bool get _cedulaLista => cedula != null || (conductor?.tieneCedula ?? false);
  bool get _tarjetaLista =>
      papelesMoto != null || (conductor?.tieneTarjetaPropiedad ?? false);
  bool get _selfieLista => selfie != null || (conductor?.tieneSelfie ?? false);
  bool get _motoLista => fotoMoto != null || (conductor?.tieneFotoMoto ?? false);

  List<String> get documentosFaltantes => [
        if (!_cedulaLista) 'cédula',
        if (!_tarjetaLista) 'tarjeta de propiedad',
        if (!_selfieLista) 'selfie',
        if (!_motoLista) 'foto de la moto',
      ];

  int get documentosListos =>
      documentosRequeridos - documentosFaltantes.length;

  double get progresoDocumentos => documentosListos / documentosRequeridos;

  /// Ubicación inicial del conductor (requerida por el backend en el alta).
  /// Null mientras el GPS no responda; al guardar cae al centro del municipio.
  LatLng? _ubicacion;

  /// Municipios donde opera la plataforma y el elegido por el conductor.
  List<Municipio> municipios = const [];
  Municipio? municipioElegido;

  void elegirMunicipio(Municipio? m) {
    municipioElegido = m;
    notifyListeners();
  }

  Conductor? get conductor => _conductores.conductor;
  bool get perfilCompleto => _conductores.perfilCompleto;

  /// La cuenta a la que se le está añadiendo el perfil de conductor.
  ///
  /// **Puede llevar años pidiendo domicilios**: entrar a esta app con la cuenta de
  /// siempre es el camino normal, no una excepción. El alta no vuelve a pedir nada
  /// que la cuenta ya tenga —nombre, celular, correo y cédula ya están—, y enseñar de
  /// quién es evita la duda de si esto va a crear una segunda cuenta.
  Usuario? cuenta;

  /// Resuelve el perfil actual y libera la pantalla enseguida; la ubicación se
  /// resuelve en segundo plano (el GPS puede tardar y no debe bloquear el alta).
  Future<void> cargar() async {
    cargando = true;
    errorCarga = null;
    notifyListeners();
    final res = await _conductores.cargar(forzar: true);
    // Solo un 404 significa "todavía no tiene perfil". Cualquier otro fallo
    // (sin señal, servidor caído) es **no saber**, y ahí no se puede enseñar el
    // alta: a un conductor ya registrado le aparecía el formulario vacío, con
    // sus cuatro documentos "pendientes", y parecía que se le había borrado todo.
    if (res case Err(failure: final f)
        when f.statusCode != 404 && _conductores.conductor == null) {
      errorCarga = f.message;
      errorCargaEsRed = f.isNetwork;
      cargando = false;
      notifyListeners();
      return;
    }
    // Municipios disponibles: preselecciona el del usuario o el único que haya.
    municipios = (await _municipios.disponibles()).valueOrNull ?? const [];
    cuenta = (await _usuarios.perfil()).valueOrNull;
    municipioElegido = _municipios.porId(cuenta?.municipioId) ??
        (municipios.isNotEmpty ? municipios.first : null);
    yaTeniaPerfil = _conductores.perfilCompleto;
    // Lo que el conductor dejó a medias la última vez. Con el perfil ya creado
    // no se restaura nada: lo que falte se sube desde "Mis documentos".
    final id = cuenta?.id;
    if (id != null && !yaTeniaPerfil) {
      borrador = await _borrador.leer(id);
      for (final e in borrador.fotos.entries) {
        _fotos.putIfAbsent(e.key, () => File(e.value));
      }
    }
    cargando = false;
    if (!_cargaLista.isCompleted) _cargaLista.complete();
    notifyListeners();
    _resolverUbicacion(); // background: no se espera
  }

  Future<void> _resolverUbicacion() async {
    final loc = await _location.obtenerUbicacion();
    if (loc.isOk) _ubicacion = loc.position!;
  }

  /// Fotos que **no se pudieron subir** en el último envío, por su nombre.
  ///
  /// Antes estos fallos se descartaban: el alta terminaba con "enviado", el
  /// conductor se iba convencido de que había mandado las cuatro fotos, y dos
  /// días después seguía sin habilitar porque al administrador le había llegado
  /// una. Ahora se dicen, y se pueden reintentar sin volver a tomarlas.
  List<String> documentosNoSubidos = const [];

  /// Tope de peso de un documento antes de subirlo. Bastante más alto que el de
  /// la evidencia de entrega: aquí hay que poder **leer** una cédula y una
  /// placa. Aun así, 1920 px a 700 KB se leen bien y suben en una fracción del
  /// tiempo con datos móviles — que es donde las subidas se caían.
  static const int _topeDocumento = 700 * 1024;
  static const int _calidadMinimaDocumento = 60;

  /// Crea el perfil y sube los documentos (cédula obligatoria, el resto no
  /// bloquea). El perfil queda PENDIENTE_VERIFICACION hasta que el admin lo
  /// habilite.
  ///
  /// Reintentable: si el perfil ya quedó creado en un intento anterior (p. ej.
  /// falló la subida de la cédula), continúa directo con los documentos en vez
  /// de chocar con el 409 de "el conductor ya tiene perfil", y no repite las
  /// fotos que ya subieron.
  Future<bool> guardar({
    String? licencia,
    required String vehiculo,
    required String placa,
  }) async {
    if (!tieneCedula) {
      error = 'Toma la foto de tu cédula para continuar';
      notifyListeners();
      return false;
    }
    // Doble toque: dos envíos son dos perfiles en carrera y dos subidas.
    if (guardando) return false;
    guardando = true;
    error = null;
    documentosNoSubidos = const [];
    notifyListeners();

    // Sin GPS, la ubicación inicial es el centro del municipio elegido (mejor
    // que un punto fijo: el matching busca conductores cerca de la recogida).
    final ubicacion = _ubicacion ??
        municipioElegido?.centro ??
        LocationService.fallbackCenter;

    if (_conductores.conductor == null) {
      final res = await _conductores.crearPerfil(
        licencia: (licencia == null || licencia.isEmpty) ? null : licencia,
        vehiculo: vehiculo,
        placa: placa,
        ubicacion: ubicacion,
      );
      if (!res.isSuccess) {
        final f = res.when(ok: (_) => null, err: (f) => f);
        if (f?.statusCode == 409) {
          // Ya existía (reintento tras un fallo a mitad): recargar y seguir.
          await _conductores.cargar(forzar: true);
        } else {
          guardando = false;
          // 403 = JWT sin rol CONDUCTOR (sesión vieja): la salida es re-loguear.
          if (f?.statusCode == 403) {
            sesionInvalida = true;
            error =
                'Tu sesión quedó desactualizada. Inicia sesión de nuevo para continuar.';
          } else {
            error = f?.message;
          }
          notifyListeners();
          return false;
        }
      }
    }

    // Perfil creado: la cédula es la única que bloquea. Si ya está en el
    // servidor de un intento anterior y no se tomó otra, no hay nada que subir.
    if (cedula != null && !_subidas.contains(DocumentoConductor.cedula)) {
      final resCedula = await _subir(DocumentoConductor.cedula);
      if (!resCedula.isSuccess) {
        guardando = false;
        final f = resCedula.when(ok: (_) => null, err: (f) => f);
        if (f?.statusCode == 403) {
          sesionInvalida = true;
          error =
              'Tu sesión quedó desactualizada. Inicia sesión de nuevo para continuar.';
        } else {
          error = (f?.isNetwork ?? false)
              ? '${f!.message} Tus fotos siguen guardadas: toca "Enviar para '
                  'revisión" otra vez.'
              : 'No pudimos subir la foto de tu cédula. Tus fotos siguen '
                  'guardadas: toca "Enviar para revisión" otra vez.';
        }
        notifyListeners();
        return false;
      }
    }

    // El resto no bloquea el alta: sin ellos el perfil se envía igual y el
    // admin no habilitará hasta tenerlos. Pero lo que no suba **se dice**.
    await _subirOpcionales();

    // Persistir el municipio del conductor (best-effort: no bloquea el alta).
    if (municipioElegido != null) {
      await _usuarios.actualizar(municipioId: municipioElegido!.id);
    }

    guardando = false;
    notifyListeners();
    return true;
  }

  /// Vuelve a intentar solo las fotos que no subieron. `true` si ya no queda
  /// ninguna pendiente.
  Future<bool> reintentarDocumentos() async {
    if (guardando) return false;
    guardando = true;
    notifyListeners();
    await _subirOpcionales();
    guardando = false;
    notifyListeners();
    return documentosNoSubidos.isEmpty;
  }

  static const _opcionales = [
    DocumentoConductor.selfie,
    DocumentoConductor.tarjetaPropiedad,
    DocumentoConductor.fotoMoto,
  ];

  Future<void> _subirOpcionales() async {
    final fallidas = <String>[];
    for (final doc in _opcionales) {
      if (_fotos[doc] == null || _subidas.contains(doc)) continue;
      var res = await _subir(doc);
      // Un segundo intento inmediato: con datos móviles la mayoría de los
      // fallos son un corte de un par de segundos.
      if (!res.isSuccess) res = await _subir(doc);
      if (!res.isSuccess) fallidas.add(doc.titulo.toLowerCase());
    }
    documentosNoSubidos = fallidas;
  }

  /// Comprime y sube la foto de un documento.
  Future<Result<void>> _subir(DocumentoConductor doc) async {
    final original = _fotos[doc]!;
    final archivo = await _compresor.aTope(
      original,
      topeBytes: _topeDocumento,
      calidadMinima: _calidadMinimaDocumento,
    );
    final MultipartFile mp;
    try {
      mp = await MultipartFile.fromFile(archivo.path);
    } catch (_) {
      // El archivo ya no está (caché vaciada): que se vuelva a tomar.
      return const Err(Failure('No encontramos la foto. Tómala de nuevo.'));
    }
    final res = await switch (doc) {
      DocumentoConductor.cedula => _conductores.subirCedula(mp),
      DocumentoConductor.tarjetaPropiedad => _conductores.subirPapelesMoto(mp),
      DocumentoConductor.selfie => _conductores.subirSelfie(mp),
      DocumentoConductor.fotoMoto => _conductores.subirFotoMoto(mp),
    };
    if (res.isSuccess) _subidas.add(doc);
    return res;
  }

  bool _desechado = false;

  @override
  void notifyListeners() {
    // Un envío puede seguir en vuelo después de cerrar la pantalla.
    if (!_desechado) super.notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}

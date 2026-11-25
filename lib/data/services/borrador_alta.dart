import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/conductor.dart';

/// Lo que el conductor lleva hecho del alta, tal como se guarda en el teléfono.
class DatosBorradorAlta {
  const DatosBorradorAlta({
    this.marca,
    this.modelo,
    this.marcaLibre = '',
    this.modeloLibre = '',
    this.placa = '',
    this.licencia = '',
    this.paso = 0,
    this.fotos = const {},
    this.capturaPendiente,
  });

  final String? marca;
  final String? modelo;
  final String marcaLibre;
  final String modeloLibre;
  final String placa;
  final String licencia;

  /// Paso del alta en el que iba (0 a 2).
  final int paso;

  /// Ruta en disco de cada foto ya tomada.
  final Map<DocumentoConductor, String> fotos;

  /// El documento para el que se abrió la cámara y aún no volvió con foto.
  ///
  /// En los teléfonos con poca memoria Android **mata la app mientras la cámara
  /// está abierta**. Al volver, el sistema entrega la foto por un canal aparte
  /// (`retrieveLostData`), pero sin decir para qué era: eso se apunta aquí antes
  /// de abrir la cámara.
  final DocumentoConductor? capturaPendiente;

  bool get vacio =>
      marca == null &&
      modelo == null &&
      marcaLibre.isEmpty &&
      modeloLibre.isEmpty &&
      placa.isEmpty &&
      licencia.isEmpty &&
      fotos.isEmpty &&
      capturaPendiente == null;

  DatosBorradorAlta copyWith({
    String? marca,
    String? modelo,
    String? marcaLibre,
    String? modeloLibre,
    String? placa,
    String? licencia,
    int? paso,
    Map<DocumentoConductor, String>? fotos,
    DocumentoConductor? capturaPendiente,
    bool limpiarCapturaPendiente = false,
    bool limpiarModelo = false,
  }) {
    return DatosBorradorAlta(
      marca: marca ?? this.marca,
      modelo: limpiarModelo ? null : (modelo ?? this.modelo),
      marcaLibre: marcaLibre ?? this.marcaLibre,
      modeloLibre: modeloLibre ?? this.modeloLibre,
      placa: placa ?? this.placa,
      licencia: licencia ?? this.licencia,
      paso: paso ?? this.paso,
      fotos: fotos ?? this.fotos,
      capturaPendiente: limpiarCapturaPendiente
          ? null
          : (capturaPendiente ?? this.capturaPendiente),
    );
  }

  Map<String, dynamic> toJson() => {
        if (marca != null) 'marca': marca,
        if (modelo != null) 'modelo': modelo,
        'marcaLibre': marcaLibre,
        'modeloLibre': modeloLibre,
        'placa': placa,
        'licencia': licencia,
        'paso': paso,
        'fotos': {for (final e in fotos.entries) e.key.name: e.value},
        if (capturaPendiente != null) 'capturaPendiente': capturaPendiente!.name,
      };

  static DatosBorradorAlta fromJson(Map<String, dynamic> m) {
    DocumentoConductor? doc(Object? nombre) {
      for (final d in DocumentoConductor.values) {
        if (d.name == nombre) return d;
      }
      return null;
    }

    final fotos = <DocumentoConductor, String>{};
    final crudas = m['fotos'];
    if (crudas is Map) {
      for (final e in crudas.entries) {
        final d = doc(e.key);
        if (d != null && e.value is String) fotos[d] = e.value as String;
      }
    }
    final paso = m['paso'];
    return DatosBorradorAlta(
      marca: m['marca'] as String?,
      modelo: m['modelo'] as String?,
      marcaLibre: m['marcaLibre'] as String? ?? '',
      modeloLibre: m['modeloLibre'] as String? ?? '',
      placa: m['placa'] as String? ?? '',
      licencia: m['licencia'] as String? ?? '',
      paso: paso is int ? paso.clamp(0, 2) : 0,
      fotos: fotos,
      capturaPendiente: doc(m['capturaPendiente']),
    );
  }
}

/// Borrador del alta de conductor, guardado en el teléfono.
///
/// **Por qué existe.** El alta son tres pasos, cuatro fotos y los datos de la
/// moto, y hasta ahora todo vivía en memoria hasta tocar "Enviar para revisión".
/// Cualquier salida antes de ese toque lo borraba: darle atrás en el primer
/// paso, cerrar la app para buscar la tarjeta de propiedad, o —el caso que nadie
/// ve venir— que Android matara la app mientras la cámara estaba abierta. El
/// conductor volvía y le faltaban las cuatro fotos que acababa de tomar.
///
/// Va **por cuenta**: dos personas que comparten teléfono no pueden heredar la
/// cédula del otro.
///
/// **Nunca rompe el alta.** Todo fallo de disco o de preferencias se traga: sin
/// borrador el alta funciona igual que antes, solo que sin memoria.
class BorradorAlta {
  BorradorAlta({
    Future<SharedPreferences> Function()? preferencias,
    Future<Directory> Function()? directorio,
  })  : _preferencias = preferencias ?? SharedPreferences.getInstance,
        _directorio = directorio ?? getApplicationSupportDirectory;

  final Future<SharedPreferences> Function() _preferencias;
  final Future<Directory> Function() _directorio;

  static String _clave(int usuarioId) => 'alta_borrador_$usuarioId';

  /// Lo guardado para esta cuenta. Las fotos cuyo archivo ya no existe se
  /// descartan: una ruta sin archivo pintaría un documento "listo" que al enviar
  /// no se puede subir.
  Future<DatosBorradorAlta> leer(int usuarioId) async {
    try {
      final prefs = await _preferencias();
      final crudo = prefs.getString(_clave(usuarioId));
      if (crudo == null) return const DatosBorradorAlta();
      final datos = DatosBorradorAlta.fromJson(
        jsonDecode(crudo) as Map<String, dynamic>,
      );
      final vivas = <DocumentoConductor, String>{
        for (final e in datos.fotos.entries)
          if (File(e.value).existsSync()) e.key: e.value,
      };
      return datos.copyWith(fotos: vivas);
    } catch (_) {
      return const DatosBorradorAlta();
    }
  }

  Future<void> guardar(int usuarioId, DatosBorradorAlta datos) async {
    try {
      final prefs = await _preferencias();
      await prefs.setString(_clave(usuarioId), jsonEncode(datos.toJson()));
    } catch (_) {
      // Sin borrador el alta sigue funcionando.
    }
  }

  /// Copia la foto recién tomada a una carpeta de la app y devuelve la copia.
  ///
  /// `image_picker` deja la foto en la caché, que el sistema puede vaciar cuando
  /// le falta espacio — justo en los teléfonos donde más se necesita el
  /// borrador. Si la copia falla se devuelve el original: mejor una foto que
  /// puede durar poco que ninguna.
  ///
  /// El nombre lleva la hora: al repetir una foto, la misma ruta haría que la
  /// miniatura siguiera mostrando la anterior (Flutter cachea por ruta).
  Future<File> conservarFoto(
    int usuarioId,
    DocumentoConductor documento,
    File origen, {
    String? anterior,
  }) async {
    try {
      final base = await _directorio();
      final carpeta = Directory('${base.path}/alta_$usuarioId');
      await carpeta.create(recursive: true);
      final punto = origen.path.lastIndexOf('.');
      final extension = punto > 0 ? origen.path.substring(punto) : '.jpg';
      final destino = File(
        '${carpeta.path}/${documento.name}_'
        '${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      final copia = await origen.copy(destino.path);
      if (anterior != null && anterior != copia.path) {
        try {
          final vieja = File(anterior);
          if (vieja.existsSync()) await vieja.delete();
        } catch (_) {}
      }
      return copia;
    } catch (_) {
      return origen;
    }
  }

  /// Borra el borrador y sus fotos. Se llama cuando el alta ya se envió: las
  /// fotos están en el servidor y aquí solo ocuparían espacio.
  Future<void> borrar(int usuarioId) async {
    try {
      final prefs = await _preferencias();
      await prefs.remove(_clave(usuarioId));
    } catch (_) {}
    try {
      final base = await _directorio();
      final carpeta = Directory('${base.path}/alta_$usuarioId');
      if (carpeta.existsSync()) await carpeta.delete(recursive: true);
    } catch (_) {}
  }
}

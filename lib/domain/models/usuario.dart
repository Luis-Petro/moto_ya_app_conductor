import 'rol.dart';

/// Modelo de dominio del usuario autenticado.
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    this.telefono,
    this.email,
    this.urlImagen,
    required this.rol,
    this.telefonoVerificado = false,
    this.municipioId,
  });

  final int id;
  final String nombre;
  final String? telefono;
  final String? email;
  final String? urlImagen;
  final Rol rol;
  final bool telefonoVerificado;

  /// Municipio elegido (id del catálogo `/municipios`); null si aún no define.
  final int? municipioId;

  /// Iniciales para el avatar (p. ej. "Marta Gómez" → "MG").
  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  String get primerNombre => nombre.trim().split(RegExp(r'\s+')).first;

  Usuario copyWith(
      {String? nombre, String? telefono, String? email, int? municipioId}) {
    return Usuario(
      id: id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      urlImagen: urlImagen,
      rol: rol,
      telefonoVerificado: telefonoVerificado,
      municipioId: municipioId ?? this.municipioId,
    );
  }
}

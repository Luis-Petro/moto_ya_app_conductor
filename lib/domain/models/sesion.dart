import 'rol.dart';

/// Sesión autenticada: el JWT propio emitido por el backend y la identidad mínima.
class Sesion {
  const Sesion({
    required this.token,
    required this.usuarioId,
    required this.rol,
  });

  final String token;
  final int usuarioId;
  final Rol rol;

  Map<String, dynamic> toJson() => {
        'token': token,
        'usuarioId': usuarioId,
        'rol': rol.wire,
      };

  factory Sesion.fromJson(Map<String, dynamic> json) => Sesion(
        token: json['token'] as String,
        usuarioId: (json['usuarioId'] as num).toInt(),
        rol: Rol.fromWire(json['rol'] as String?),
      );
}

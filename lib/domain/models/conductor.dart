import 'package:latlong2/latlong.dart';

/// Estado operativo del conductor (espejo del enum backend `EstadoConductor`).
enum EstadoConductor {
  activo('ACTIVO'),
  bloqueadoPorDeuda('BLOQUEADO_POR_DEUDA');

  const EstadoConductor(this.wire);

  final String wire;

  static EstadoConductor fromWire(String? value) {
    return EstadoConductor.values.firstWhere(
      (e) => e.wire == value,
      orElse: () => EstadoConductor.activo,
    );
  }

  bool get bloqueado => this == EstadoConductor.bloqueadoPorDeuda;
}

/// Perfil de conductor (espejo de la entidad backend `Conductor`).
class Conductor {
  const Conductor({
    required this.id,
    required this.usuarioId,
    this.licencia,
    this.vehiculo,
    this.placa,
    this.documentoUrl,
    this.enLinea = false,
    this.ubicacion,
    this.ultimaConexion,
    this.deudaActual = 0,
    this.calificacion,
    this.tasaAceptacion,
    this.tasaCancelacion,
    this.tiempoRespuestaSeg,
    this.estado = EstadoConductor.activo,
  });

  final int id;
  final int usuarioId;
  final String? licencia;
  final String? vehiculo;
  final String? placa;
  final String? documentoUrl;
  final bool enLinea;
  final LatLng? ubicacion;
  final DateTime? ultimaConexion;
  final double deudaActual;
  final double? calificacion;
  final double? tasaAceptacion;
  final double? tasaCancelacion;
  final int? tiempoRespuestaSeg;
  final EstadoConductor estado;

  /// El perfil tiene los datos mínimos para operar (matching lo exige).
  bool get perfilCompleto =>
      (licencia?.trim().isNotEmpty ?? false) &&
      (vehiculo?.trim().isNotEmpty ?? false) &&
      (placa?.trim().isNotEmpty ?? false);

  bool get bloqueadoPorDeuda => estado.bloqueado;

  bool get tieneDocumentos => documentoUrl?.trim().isNotEmpty ?? false;

  Conductor copyWith({
    bool? enLinea,
    LatLng? ubicacion,
    double? deudaActual,
    EstadoConductor? estado,
  }) {
    return Conductor(
      id: id,
      usuarioId: usuarioId,
      licencia: licencia,
      vehiculo: vehiculo,
      placa: placa,
      documentoUrl: documentoUrl,
      enLinea: enLinea ?? this.enLinea,
      ubicacion: ubicacion ?? this.ubicacion,
      ultimaConexion: ultimaConexion,
      deudaActual: deudaActual ?? this.deudaActual,
      calificacion: calificacion,
      tasaAceptacion: tasaAceptacion,
      tasaCancelacion: tasaCancelacion,
      tiempoRespuestaSeg: tiempoRespuestaSeg,
      estado: estado ?? this.estado,
    );
  }
}

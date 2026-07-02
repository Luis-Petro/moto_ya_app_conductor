import 'package:latlong2/latlong.dart';

/// Estado operativo del conductor (espejo del enum backend `EstadoConductor`).
enum EstadoConductor {
  pendienteVerificacion('PENDIENTE_VERIFICACION'),
  activo('ACTIVO'),
  bloqueadoPorDeuda('BLOQUEADO_POR_DEUDA'),
  rechazado('RECHAZADO');

  const EstadoConductor(this.wire);

  final String wire;

  static EstadoConductor fromWire(String? value) {
    return EstadoConductor.values.firstWhere(
      (e) => e.wire == value,
      orElse: () => EstadoConductor.pendienteVerificacion,
    );
  }

  bool get bloqueado => this == EstadoConductor.bloqueadoPorDeuda;

  /// Cuenta aún no habilitada por el admin (pendiente o rechazada): no opera.
  bool get enRevision => this == EstadoConductor.pendienteVerificacion;
  bool get rechazadoPorAdmin => this == EstadoConductor.rechazado;

  /// Único estado que puede ponerse en línea y recibir pedidos.
  bool get habilitado => this == EstadoConductor.activo;
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
    this.fotoUrl,
    this.cedulaUrl,
    this.papelesMotoUrl,
    this.enLinea = false,
    this.ubicacion,
    this.ultimaConexion,
    this.deudaActual = 0,
    this.calificacion,
    this.tasaAceptacion,
    this.tasaCancelacion,
    this.tiempoRespuestaSeg,
    this.estado = EstadoConductor.pendienteVerificacion,
    this.motivoRechazo,
  });

  final int id;
  final int usuarioId;
  final String? licencia;
  final String? vehiculo;
  final String? placa;
  final String? documentoUrl;
  final String? fotoUrl;
  final String? cedulaUrl;
  final String? papelesMotoUrl;
  final bool enLinea;
  final LatLng? ubicacion;
  final DateTime? ultimaConexion;
  final double deudaActual;
  final double? calificacion;
  final double? tasaAceptacion;
  final double? tasaCancelacion;
  final int? tiempoRespuestaSeg;
  final EstadoConductor estado;
  final String? motivoRechazo;

  /// El perfil tiene los datos mínimos para operar (matching lo exige).
  bool get perfilCompleto =>
      (licencia?.trim().isNotEmpty ?? false) &&
      (vehiculo?.trim().isNotEmpty ?? false) &&
      (placa?.trim().isNotEmpty ?? false);

  bool get bloqueadoPorDeuda => estado.bloqueado;

  /// La cuenta aún no está habilitada para recibir pedidos.
  bool get enRevision => estado.enRevision;
  bool get rechazado => estado.rechazadoPorAdmin;
  bool get habilitado => estado.habilitado;
  bool get tieneCedula => cedulaUrl?.trim().isNotEmpty ?? false;

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
      fotoUrl: fotoUrl,
      cedulaUrl: cedulaUrl,
      papelesMotoUrl: papelesMotoUrl,
      enLinea: enLinea ?? this.enLinea,
      ubicacion: ubicacion ?? this.ubicacion,
      ultimaConexion: ultimaConexion,
      deudaActual: deudaActual ?? this.deudaActual,
      calificacion: calificacion,
      tasaAceptacion: tasaAceptacion,
      tasaCancelacion: tasaCancelacion,
      tiempoRespuestaSeg: tiempoRespuestaSeg,
      estado: estado ?? this.estado,
      motivoRechazo: motivoRechazo,
    );
  }
}

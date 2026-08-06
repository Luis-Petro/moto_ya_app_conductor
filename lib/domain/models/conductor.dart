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

/// Los cuatro documentos que el admin exige para habilitar la cuenta.
enum DocumentoConductor {
  cedula('Cédula', 'Solo el lado de adelante, donde está tu foto.'),
  tarjetaPropiedad('Tarjeta de propiedad',
      'La tarjeta de la moto, donde aparece la placa y tu nombre.'),
  selfie('Selfie tuya',
      'De frente, con buena luz y sin casco ni gafas oscuras.'),
  fotoMoto('Foto de tu moto', 'De lado o desde atrás, con la placa legible.');

  const DocumentoConductor(this.titulo, this.guia);

  final String titulo;
  final String guia;
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
    this.selfieUrl,
    this.fotoMotoUrl,
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

  /// Tarjeta de propiedad de la moto (el campo del backend conserva el nombre
  /// `papelesMotoUrl`).
  final String? papelesMotoUrl;

  /// Selfie de verificación (la cara del conductor).
  final String? selfieUrl;

  /// Foto de la moto con la placa visible.
  final String? fotoMotoUrl;
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
  /// La licencia es opcional por ahora: no puede condicionar este flag o el
  /// conductor rebotaría al alta en cada apertura de la app.
  bool get perfilCompleto =>
      (vehiculo?.trim().isNotEmpty ?? false) &&
      (placa?.trim().isNotEmpty ?? false);

  bool get bloqueadoPorDeuda => estado.bloqueado;

  /// La cuenta aún no está habilitada para recibir pedidos.
  bool get enRevision => estado.enRevision;
  bool get rechazado => estado.rechazadoPorAdmin;
  bool get habilitado => estado.habilitado;
  bool get tieneCedula => cedulaUrl?.trim().isNotEmpty ?? false;
  bool get tieneTarjetaPropiedad => papelesMotoUrl?.trim().isNotEmpty ?? false;
  bool get tieneSelfie => selfieUrl?.trim().isNotEmpty ?? false;
  bool get tieneFotoMoto => fotoMotoUrl?.trim().isNotEmpty ?? false;

  /// Documentos que el admin exige para habilitar la cuenta y aún faltan.
  /// Mismos nombres que usa el backend al rechazar la habilitación, para que
  /// el conductor lea lo mismo aquí y en el mensaje de error.
  List<String> get documentosFaltantes => [
        if (!tieneCedula) 'cédula',
        if (!tieneTarjetaPropiedad) 'tarjeta de propiedad',
        if (!tieneSelfie) 'selfie',
        if (!tieneFotoMoto) 'foto de la moto',
      ];

  /// Cuántos de los cuatro documentos ya están subidos.
  int get documentosSubidos => 4 - documentosFaltantes.length;

  /// URL del documento [doc], o null si aún no se ha subido.
  String? urlDocumento(DocumentoConductor doc) {
    final v = switch (doc) {
      DocumentoConductor.cedula => cedulaUrl,
      DocumentoConductor.tarjetaPropiedad => papelesMotoUrl,
      DocumentoConductor.selfie => selfieUrl,
      DocumentoConductor.fotoMoto => fotoMotoUrl,
    };
    return (v?.trim().isNotEmpty ?? false) ? v : null;
  }

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
      selfieUrl: selfieUrl,
      fotoMotoUrl: fotoMotoUrl,
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

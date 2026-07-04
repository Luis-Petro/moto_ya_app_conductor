import 'package:latlong2/latlong.dart';

import '../../domain/models/billetera.dart';
import '../../domain/models/calificacion.dart';
import '../../domain/models/categoria_servicio.dart';
import '../../domain/models/conductor.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/municipio.dart';
import '../../domain/models/pedido.dart';
import '../../domain/models/propuesta_tarifa.dart';
import '../../domain/models/reputacion_conductor.dart';
import '../../domain/models/rol.dart';
import '../../domain/models/sesion.dart';
import '../../domain/models/usuario.dart';

/// Funciones de mapeo JSON → modelos de dominio. Mantienen el dominio puro
/// (sin dependencia de serialización) y son tolerantes a campos ausentes.
class ApiMappers {
  const ApiMappers._();

  static Sesion sesion(dynamic json) {
    final m = json as Map<String, dynamic>;
    return Sesion(
      token: m['token'] as String,
      usuarioId: _int(m['usuarioId'])!,
      rol: Rol.fromWire(m['rol'] as String?),
    );
  }

  static Usuario usuario(dynamic json) {
    final m = json as Map<String, dynamic>;
    return Usuario(
      id: _int(m['id'])!,
      nombre: (m['nombre'] as String?) ?? '',
      telefono: m['telefono'] as String?,
      email: m['email'] as String?,
      urlImagen: m['urlImagen'] as String?,
      rol: Rol.fromWire(m['rol'] as String?),
      telefonoVerificado: (m['telefonoVerificado'] as bool?) ?? false,
      municipioId: _int(m['municipioId']),
    );
  }

  static Municipio municipio(dynamic json) {
    final m = json as Map<String, dynamic>;
    final lat = _double(m['centroLat']);
    final lng = _double(m['centroLng']);
    return Municipio(
      id: _int(m['id'])!,
      departamento: (m['departamento'] as String?) ?? '',
      nombre: (m['nombre'] as String?) ?? '',
      centro: (lat != null && lng != null) ? LatLng(lat, lng) : null,
    );
  }

  static Conductor conductor(dynamic json) {
    final m = json as Map<String, dynamic>;
    return Conductor(
      id: _int(m['id'])!,
      usuarioId: _int(m['usuarioId']) ?? 0,
      licencia: m['licencia'] as String?,
      vehiculo: m['vehiculo'] as String?,
      placa: m['placa'] as String?,
      documentoUrl: m['documentoUrl'] as String?,
      fotoUrl: m['fotoUrl'] as String?,
      cedulaUrl: m['cedulaUrl'] as String?,
      papelesMotoUrl: m['papelesMotoUrl'] as String?,
      enLinea: (m['enLinea'] as bool?) ?? false,
      ubicacion: _latLng(m['ubicacionLat'], m['ubicacionLng']),
      ultimaConexion: _date(m['ultimaConexion']),
      deudaActual: _double(m['deudaActual']) ?? 0,
      calificacion: _double(m['calificacion']),
      tasaAceptacion: _double(m['tasaAceptacion']),
      tasaCancelacion: _double(m['tasaCancelacion']),
      tiempoRespuestaSeg: _int(m['tiempoRespuestaSeg']),
      estado: EstadoConductor.fromWire(m['estado'] as String?),
      motivoRechazo: m['motivoRechazo'] as String?,
    );
  }

  static Billetera billetera(dynamic json) {
    final m = json as Map<String, dynamic>;
    return Billetera(
      deudaActual: _double(m['deudaActual']) ?? 0,
      limite: _double(m['limite']) ?? _double(m['limiteDeuda']) ?? 0,
      estado: EstadoConductor.fromWire(m['estado'] as String?),
    );
  }

  static DatosPago datosPago(dynamic json) {
    final m = json as Map<String, dynamic>;
    return DatosPago(
      nequiNumero: m['nequiNumero'] as String?,
      nequiTitular: m['nequiTitular'] as String?,
      brebLlave: m['brebLlave'] as String?,
      brebTitular: m['brebTitular'] as String?,
      brebEntidad: m['brebEntidad'] as String?,
    );
  }

  static IntencionPago intencionPago(dynamic json) {
    final m = json as Map<String, dynamic>;
    return IntencionPago(
      pagoId: _int(m['id']) ?? _int(m['pagoId']) ?? 0,
      medioPago: (m['medioPago'] as String?) == MedioPago.breB.wire
          ? MedioPago.breB
          : MedioPago.nequi,
      monto: _double(m['valor']) ?? _double(m['monto']) ?? 0,
      estado: (m['estado'] as String?) ?? 'PENDIENTE',
      referenciaExterna: m['referenciaExterna'] as String?,
      urlPago: m['urlPago'] as String?,
      instrucciones: m['instrucciones'] as String?,
    );
  }

  static Pedido pedido(dynamic json) {
    final m = json as Map<String, dynamic>;
    return Pedido(
      id: _int(m['id'])!,
      clienteId: _int(m['clienteId']) ?? 0,
      conductorId: _int(m['conductorId']),
      categoria: CategoriaServicio.fromWire(m['categoria'] as String?),
      descripcion: (m['descripcion'] as String?) ?? '',
      origen: _latLng(m['origenLat'], m['origenLng']),
      destino: _latLng(m['destinoLat'], m['destinoLng']),
      direccionRecogida: m['direccionRecogida'] as String?,
      direccionDestino: m['direccionDestino'] as String?,
      referencia: m['referencia'] as String?,
      fotoUrl: m['fotoUrl'] as String?,
      tarifaSugerida: _double(m['tarifaSugerida']),
      tarifaEstimada: (m['tarifaEstimada'] as bool?) ?? false,
      tarifaFinal: _double(m['tarifaFinal']),
      requiereCompra: (m['requiereCompra'] as bool?) ?? false,
      montoCompraEstimado: _double(m['montoCompraEstimado']),
      estado: EstadoPedido.fromWire(m['estado'] as String?),
      motivoCancelacion: m['motivoCancelacion'] as String?,
      creadoEn: _date(m['creadoEn']),
      entregadoEn: _date(m['entregadoEn']),
      clienteNombre: m['clienteNombre'] as String?,
      clienteTelefono: m['clienteTelefono'] as String?,
      distanciaEstimadaMetros: _double(m['distanciaEstimadaMetros']),
      duracionEstimadaSegundos: _double(m['duracionEstimadaSegundos']),
      rutaPolyline: m['rutaPolyline'] as String?,
    );
  }

  static List<Pedido> pedidos(dynamic json) =>
      (json as List).map(pedido).toList();

  static PropuestaTarifa propuesta(dynamic json) {
    final m = json as Map<String, dynamic>;
    return PropuestaTarifa(
      id: _int(m['id'])!,
      pedidoId: _int(m['pedidoId']) ?? 0,
      conductorId: _int(m['conductorId']) ?? 0,
      valorPropuesto: _double(m['valorPropuesto']) ?? 0,
      esContraoferta: (m['esContraoferta'] as bool?) ?? false,
      estado: (m['estado'] as String?) ?? 'ENVIADA',
      fecha: _date(m['fecha']),
    );
  }

  static List<PropuestaTarifa> propuestas(dynamic json) =>
      (json as List).map(propuesta).toList();

  static Calificacion calificacion(dynamic json) {
    final m = json as Map<String, dynamic>;
    return Calificacion(
      puntaje: _int(m['puntaje']) ?? 0,
      comentario: m['comentario'] as String?,
      creadoEn: _date(m['creadoEn']),
    );
  }

  static ReputacionConductor reputacion(dynamic json) {
    final m = json as Map<String, dynamic>;
    return ReputacionConductor(
      calificacion: _double(m['calificacion']),
      tasaAceptacion: _double(m['tasaAceptacion']),
      tasaCancelacion: _double(m['tasaCancelacion']),
      tiempoRespuestaSeg: _int(m['tiempoRespuestaSeg']),
    );
  }

  // ── Helpers ──

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _double(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    final s = v.toString();
    return DateTime.tryParse(s);
  }

  static LatLng? _latLng(dynamic lat, dynamic lng) {
    final la = _double(lat);
    final ln = _double(lng);
    return (la != null && ln != null) ? LatLng(la, ln) : null;
  }
}

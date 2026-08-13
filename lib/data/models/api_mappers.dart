import 'package:latlong2/latlong.dart';

import '../../domain/models/billetera.dart';
import '../../domain/models/calificacion.dart';
import '../../domain/models/categoria_servicio.dart';
import '../../domain/models/conductor.dart';
import '../../domain/models/demanda_zonas.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/lugar.dart';
import '../../domain/models/municipio.dart';
import '../../domain/models/oferta.dart';
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
      emailVerificado: (m['emailVerificado'] as bool?) ?? false,
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

  static Lugar lugar(dynamic json) {
    final m = json as Map<String, dynamic>;
    return Lugar(
      id: _int(m['id'])!,
      nombre: (m['nombre'] as String?) ?? '',
      categoria: CategoriaLugar.desdeApi(m['categoria'] as String?),
      punto: LatLng(_double(m['lat']) ?? 0, _double(m['lng']) ?? 0),
      referencia: m['referencia'] as String?,
      forma: _forma(m['forma']),
    );
  }

  /// Vértices del área de un lugar, `[[lat,lng],…]`.
  ///
  /// **Tolerante a propósito**: una forma malformada devuelve `null` y el lugar
  /// se dibuja como punto. Esta respuesta trae el municipio entero, así que un
  /// trazo corrupto no puede dejar la pantalla sin mapa. El par es `[lat, lng]`,
  /// no el orden inverso de GeoJSON.
  static List<LatLng>? _forma(dynamic valor) {
    if (valor is! List || valor.length < 3) return null;
    final puntos = <LatLng>[];
    for (final par in valor) {
      if (par is! List || par.length != 2) return null;
      final lat = _double(par[0]);
      final lng = _double(par[1]);
      if (lat == null || lng == null) return null;
      puntos.add(LatLng(lat, lng));
    }
    return puntos;
  }

  /// Demanda reciente por zonas. `celdas` puede llegar vacía: es un dato
  /// legítimo ("no hay suficientes pedidos"), no un fallo de mapeo.
  static DemandaZonas demandaZonas(dynamic json) {
    final m = json as Map<String, dynamic>;
    final celdas = (m['celdas'] as List? ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .map((c) {
          final centro = _latLng(c['centroLat'], c['centroLng']);
          if (centro == null) return null;
          return CeldaDemanda(
            centro: centro,
            pedidos: _int(c['pedidos']) ?? 0,
            nivel: NivelDemanda.fromWire(c['nivel'] as String?),
          );
        })
        .whereType<CeldaDemanda>()
        .toList();
    return DemandaZonas(
      periodoHoras: _int(m['periodoHoras']) ?? 2,
      totalPedidos: _int(m['totalPedidos']) ?? 0,
      actualizadoEn: _date(m['actualizadoEn']) ?? DateTime.now(),
      celdas: celdas,
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
      selfieUrl: m['selfieUrl'] as String?,
      fotoMotoUrl: m['fotoMotoUrl'] as String?,
      enLinea: (m['enLinea'] as bool?) ?? false,
      ubicacion: _latLng(m['ubicacionLat'], m['ubicacionLng']),
      ultimaConexion: _date(m['ultimaConexion']),
      deudaActual: _double(m['deudaActual']) ?? 0,
      calificacion: _double(m['calificacion']),
      tasaAceptacion: _double(m['tasaAceptacion']),
      tasaCancelacion: _double(m['tasaCancelacion']),
      tiempoRespuestaSeg: _int(m['tiempoRespuestaSeg']),
      estado: EstadoConductor.fromWire(m['estado'] as String?),
      verificadoEn: _date(m['verificadoEn']),
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

  static PagoRealizado pago(dynamic json) {
    final m = json as Map<String, dynamic>;
    return PagoRealizado(
      id: _int(m['id']) ?? 0,
      valor: _double(m['valor']) ?? 0,
      medioPago: (m['medioPago'] as String?) == MedioPago.breB.wire
          ? MedioPago.breB
          : MedioPago.nequi,
      estado: (m['estado'] as String?) ?? 'PENDIENTE',
      referenciaExterna: m['referenciaExterna'] as String?,
      cuentaOrigen: m['cuentaOrigen'] as String?,
      titularOrigen: m['titularOrigen'] as String?,
      entidadOrigen: m['entidadOrigen'] as String?,
      comprobanteUrl: m['comprobanteUrl'] as String?,
      creadoEn: _date(m['creadoEn']),
      confirmadoEn: _date(m['confirmadoEn']),
    );
  }

  static List<PagoRealizado> pagos(dynamic json) =>
      (json as List).map(pago).toList();

  static MovimientoSaldo movimientoSaldo(dynamic json) {
    final m = json as Map<String, dynamic>;
    return MovimientoSaldo(
      id: _int(m['id']) ?? 0,
      valor: _double(m['valor']) ?? 0,
      concepto: (m['concepto'] as String?) ?? 'OTRO',
      nota: (m['nota'] as String?) ?? '',
      creadoEn: _date(m['creadoEn']),
    );
  }

  static List<MovimientoSaldo> movimientosSaldo(dynamic json) =>
      (json as List).map(movimientoSaldo).toList();

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
      referenciaRecogida: m['referenciaRecogida'] as String?,
      referencia: m['referencia'] as String?,
      fotoUrl: m['fotoUrl'] as String?,
      tarifaSugerida: _double(m['tarifaSugerida']),
      tarifaEstimada: (m['tarifaEstimada'] as bool?) ?? false,
      tarifaFinal: _double(m['tarifaFinal']),
      recargoAdelanto: _double(m['recargoAdelanto']),
      recargoEspera: _double(m['recargoEspera']),
      requiereCompra: (m['requiereCompra'] as bool?) ?? false,
      montoCompraEstimado: _double(m['montoCompraEstimado']),
      requiereEspera: (m['requiereEspera'] as bool?) ?? false,
      minutosEsperaEstimados: _int(m['minutosEsperaEstimados']),
      estado: EstadoPedido.fromWire(m['estado'] as String?),
      motivoCancelacion: m['motivoCancelacion'] as String?,
      creadoEn: _date(m['creadoEn']),
      entregadoEn: _date(m['entregadoEn']),
      clienteNombre: m['clienteNombre'] as String?,
      clienteTelefono: m['clienteTelefono'] as String?,
      clienteFotoUrl: m['clienteFotoUrl'] as String?,
      distanciaEstimadaMetros: _double(m['distanciaEstimadaMetros']),
      duracionEstimadaSegundos: _double(m['duracionEstimadaSegundos']),
      rutaPolyline: m['rutaPolyline'] as String?,
    );
  }

  static List<Pedido> pedidos(dynamic json) =>
      (json as List).map(pedido).toList();

  /// Oferta dirigida vigente: envuelve el pedido con la ventana del servidor
  /// (`GET /pedidos/ofertas` devuelve `{pedido, expiraEn, segundosRestantes}`).
  static Oferta oferta(dynamic json) {
    final m = json as Map<String, dynamic>;
    return Oferta(
      pedido: pedido(m['pedido']),
      expiraEnMillis: _int(m['expiraEn']) ?? 0,
      segundosRestantes: _int(m['segundosRestantes']) ?? 0,
    );
  }

  static List<Oferta> ofertas(dynamic json) =>
      (json as List).map(oferta).toList();

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

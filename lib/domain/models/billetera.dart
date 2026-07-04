import 'conductor.dart';

/// Estado de la billetera del conductor: deuda de comisiones frente al límite
/// configurable de la plataforma. Es la fuente de verdad para el gating de
/// "En línea" (design D7: REST manda en dinero/estado).
class Billetera {
  const Billetera({
    required this.deudaActual,
    required this.limite,
    this.estado = EstadoConductor.activo,
  });

  /// Comisiones pendientes acumuladas. Negativa = saldo a favor (abonos que
  /// consumen las próximas comisiones antes de generar deuda).
  final double deudaActual;

  /// Límite de deuda configurable de la plataforma.
  final double limite;

  final EstadoConductor estado;

  bool get bloqueado => estado.bloqueado;

  /// True cuando hay comisiones por pagar.
  bool get enDeuda => deudaActual > 0;

  /// Saldo a favor del conductor (0 si está en deuda o al día exacto).
  double get saldoAFavor => deudaActual < 0 ? -deudaActual : 0;

  /// Fracción del límite usada (0..1+). Puede superar 1 si está bloqueado; con
  /// saldo a favor es 0.
  double get fraccionUso {
    if (limite <= 0 || deudaActual <= 0) return 0;
    return deudaActual / limite;
  }

  /// Porcentaje del límite usado, redondeado (p. ej. 102).
  int get porcentajeUso => (fraccionUso * 100).round();

  /// Cupo restante antes del bloqueo (nunca negativo).
  double get disponible {
    final d = limite - deudaActual;
    return d < 0 ? 0 : d;
  }

  Billetera copyWith({double? deudaActual, double? limite, EstadoConductor? estado}) {
    return Billetera(
      deudaActual: deudaActual ?? this.deudaActual,
      limite: limite ?? this.limite,
      estado: estado ?? this.estado,
    );
  }
}

/// Datos de destino a donde el conductor transfiere para pagar comisiones
/// (administrados desde el panel). Nequi por número; Bre-B por llave.
class DatosPago {
  const DatosPago({
    this.nequiNumero,
    this.nequiTitular,
    this.brebLlave,
    this.brebTitular,
    this.brebEntidad,
  });

  final String? nequiNumero;
  final String? nequiTitular;
  final String? brebLlave;
  final String? brebTitular;
  final String? brebEntidad;

  /// True si hay datos configurados para [medio].
  bool tieneDatos(MedioPago medio) => medio == MedioPago.nequi
      ? (nequiNumero != null && nequiNumero!.isNotEmpty)
      : (brebLlave != null && brebLlave!.isNotEmpty);
}

/// Medio de pago para liquidar la deuda (espejo del enum backend `MedioPago`).
enum MedioPago {
  nequi('NEQUI', 'Nequi'),
  breB('BRE_B', 'Bre-B');

  const MedioPago(this.wire, this.label);

  final String wire;
  final String label;
}

/// Intención de pago devuelta por el backend al iniciar un pago. La confirmación
/// real llega por webhook del proveedor (design D8: confirmación asíncrona).
class IntencionPago {
  const IntencionPago({
    required this.pagoId,
    required this.medioPago,
    required this.monto,
    this.estado = 'PENDIENTE',
    this.referenciaExterna,
    this.urlPago,
    this.instrucciones,
  });

  final int pagoId;
  final MedioPago medioPago;
  final double monto;

  /// PENDIENTE | CONFIRMADO | FALLIDO.
  final String estado;
  final String? referenciaExterna;

  /// Enlace/deeplink del proveedor para completar el pago, si aplica.
  final String? urlPago;

  /// Instrucciones del proveedor para completar el pago (texto legible).
  final String? instrucciones;

  bool get pendiente => estado == 'PENDIENTE';
  bool get confirmado => estado == 'CONFIRMADO';

  IntencionPago copyWith({String? estado}) {
    return IntencionPago(
      pagoId: pagoId,
      medioPago: medioPago,
      monto: monto,
      estado: estado ?? this.estado,
      referenciaExterna: referenciaExterna,
      urlPago: urlPago,
      instrucciones: instrucciones,
    );
  }
}

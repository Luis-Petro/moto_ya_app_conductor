import 'package:intl/intl.dart';

/// Utilidades de formato (moneda COP, fechas) centralizadas.
class Formato {
  const Formato._();

  static final NumberFormat _cop = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  static final DateFormat _fechaHora = DateFormat("d MMM, h:mm a", 'es_CO');

  /// Formatea un valor monetario en pesos colombianos sin decimales.
  static String moneda(num? valor) {
    if (valor == null) return '—';
    return _cop.format(valor);
  }

  /// Diferencia firmada respecto a una base (p. ej. "+\$2.000" / "-\$1.000").
  static String diferencia(num valor, num base) {
    final delta = valor - base;
    final signo = delta >= 0 ? '+' : '-';
    return '$signo${_cop.format(delta.abs())}';
  }

  static String fechaHora(DateTime? fecha) {
    if (fecha == null) return '';
    return _fechaHora.format(fecha.toLocal());
  }
}

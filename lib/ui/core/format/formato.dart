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
  static final DateFormat _dia = DateFormat("EEEE d 'de' MMMM", 'es_CO');
  static final DateFormat _hora = DateFormat('h:mm a', 'es_CO');

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

  /// Etiqueta de día para separadores de listas: "Hoy", "Ayer" o
  /// "martes 30 de junio".
  static String dia(DateTime fecha) {
    final f = fecha.toLocal();
    final hoy = DateTime.now();
    final soloDia = DateTime(f.year, f.month, f.day);
    final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final delta = soloHoy.difference(soloDia).inDays;
    if (delta == 0) return 'Hoy';
    if (delta == 1) return 'Ayer';
    return _dia.format(f);
  }

  /// Hora corta ("3:45 p. m.") para ítems agrupados bajo un separador de día.
  static String hora(DateTime? fecha) {
    if (fecha == null) return '';
    return _hora.format(fecha.toLocal());
  }

  /// Distancia legible: metros si <1 km, si no km con un decimal (es_CO).
  static String distancia(num? metros) {
    if (metros == null) return '—';
    if (metros < 1000) return '${metros.round()} m';
    final km = metros / 1000;
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// Duración legible a partir de segundos: "X min" o "Xh Ym".
  static String duracion(num? segundos) {
    if (segundos == null) return '—';
    final min = (segundos / 60).round();
    if (min < 60) return '$min min';
    final h = min ~/ 60;
    final m = min % 60;
    return m > 0 ? '${h}h ${m}min' : '${h}h';
  }
}

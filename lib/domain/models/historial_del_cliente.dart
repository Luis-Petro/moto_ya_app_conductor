import 'pedido.dart';

/// El rótulo con el que el conductor lee, de un vistazo, cuánta plata ha movido
/// ya este cliente por la plataforma.
///
/// Es quien va a poner el dinero de su bolsillo: un tope que decide el sistema
/// en silencio le quita la última palabra a quien asume el riesgo. La decisión
/// sigue siendo suya — puede rechazar la oferta con el mecanismo de siempre y
/// sin ninguna penalización distinta de la de rechazar cualquier otra.
///
/// Devuelve `null` cuando **no hay nada que decir**, y son tres casos que se
/// pintan igual a propósito: el pedido no exige adelantar dinero, el backend no
/// mandó el dato (una versión anterior), o no se pudo resolver. En los tres, la
/// tarjeta se queda exactamente como estaba antes de que este rótulo existiera.
///
/// Vive en `domain` y no en cada pantalla porque lo usan la tarjeta de oferta y
/// el pedido en curso: escrito dos veces, un día dirían cosas distintas sobre la
/// misma persona.
String? historialDelCliente(Pedido pedido) {
  if (!pedido.requiereCompra) return null;
  final completados = pedido.pedidosConAdelantoDelCliente;
  if (completados == null) return null;
  // Sin cifra que interpretar: "0 pedidos" se lee como un dato averiado, y lo
  // que hay que comunicar es que no hay historial todavía.
  if (completados <= 0) return 'Cliente nuevo · sin pedidos con compra';
  if (completados == 1) return '1 pedido con compra completado';
  return '$completados pedidos con compra completados';
}

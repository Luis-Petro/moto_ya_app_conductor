/// Un artículo del catálogo que el cliente eligió y el conductor va a comprar.
///
/// El nombre y el precio son **los que se copiaron al crear el pedido**, no los
/// que hoy tenga el catálogo del negocio: un pedido ya en curso no se reescribe
/// porque el aliado corrija su lista de precios. Que puedan no coincidir con la
/// caja del negocio es exactamente el motivo de que exista el importe real al
/// entregar.
class ItemPedido {
  const ItemPedido({
    this.productoId,
    required this.cantidad,
    required this.nombre,
    this.precioUnitario,
    this.subtotal,
    this.nota,
  });

  /// El producto del catálogo. Puede ser nulo si el negocio lo borró después:
  /// el pedido sigue siendo válido porque el nombre y el precio están copiados.
  final int? productoId;

  final int cantidad;
  final String nombre;
  final double? precioUnitario;
  final double? subtotal;

  /// Lo que el cliente pidió de ese artículo en concreto ("sin cebolla").
  ///
  /// **Es el motivo por el que esta lista existe en la pantalla del conductor.**
  /// La descripción generada del pedido dice qué y cuánto, pero una nota por
  /// artículo en un párrafo corrido se lee mal en una moto, y es justo lo que hay
  /// que decirle a quien atiende en el negocio.
  final String? nota;
}

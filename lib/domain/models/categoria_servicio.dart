import 'package:flutter/material.dart';

/// Categorías de servicio soportadas por la plataforma (espejo del enum del
/// backend `CategoriaServicio`).
enum CategoriaServicio {
  comida('COMIDA', 'Comida', Icons.restaurant),
  farmacia('FARMACIA', 'Farmacia', Icons.local_pharmacy_outlined),
  mercado('MERCADO', 'Mercado', Icons.storefront_outlined),
  mandado('MANDADO', 'Mandados', Icons.inventory_2_outlined);

  const CategoriaServicio(this.wire, this.label, this.icon);

  /// Valor exacto enviado/recibido por la API.
  final String wire;

  /// Etiqueta para la UI.
  final String label;

  final IconData icon;

  static CategoriaServicio fromWire(String? value) {
    return CategoriaServicio.values.firstWhere(
      (c) => c.wire == value,
      orElse: () => CategoriaServicio.mandado,
    );
  }
}

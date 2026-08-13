import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/services/lugar_service.dart';
import '../../../di/locator.dart';
import '../../../domain/models/lugar.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'primary_button.dart';

/// Hoja para que el conductor guarde el punto de una entrega como lugar del
/// catálogo.
///
/// Es el motor real del catálogo: OpenStreetMap casi no tiene comercio mapeado
/// en municipios pequeños, y el conductor es el único que ya estuvo en la
/// puerta. Cada punto que aporta le ahorra al próximo cliente adivinar en el
/// mapa.
///
/// Se abre con [mostrarProponerLugar]. Usa `showModalBottomSheet`, cuyo
/// `useRootNavigator` por defecto es `false` y por tanto no pinta el velo negro
/// sobre el shell (ver gotcha de go_router + StatefulShellRoute).
Future<bool?> mostrarProponerLugar(
  BuildContext context, {
  required LatLng punto,
  int? municipioId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (contextoHoja) => Padding(
      // El MediaQuery tiene que ser el de la hoja, no el de quien la abrió: con
      // el context de fuera, viewInsets se queda en 0 y el teclado tapa los
      // campos y el botón en vez de empujar la hoja hacia arriba.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(contextoHoja).viewInsets.bottom,
      ),
      child: _ProponerLugarSheet(punto: punto, municipioId: municipioId),
    ),
  );
}

class _ProponerLugarSheet extends StatefulWidget {
  const _ProponerLugarSheet({required this.punto, this.municipioId});

  final LatLng punto;
  final int? municipioId;

  @override
  State<_ProponerLugarSheet> createState() => _ProponerLugarSheetState();
}

class _ProponerLugarSheetState extends State<_ProponerLugarSheet> {
  final _nombre = TextEditingController();
  final _referencia = TextEditingController();
  final _service = locator<LugarService>();

  CategoriaLugar _categoria = CategoriaLugar.comercio;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _referencia.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre del lugar');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final res = await _service.proponer(
      nombre: nombre,
      categoria: _categoria,
      lat: widget.punto.latitude,
      lng: widget.punto.longitude,
      referencia: _referencia.text,
      municipioId: widget.municipioId,
    );
    if (!mounted) return;
    res.when(
      ok: (_) => Navigator.of(context).pop(true),
      err: (f) => setState(() {
        _enviando = false;
        _error = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Desplazable: con el teclado abierto en un teléfono corto, el contenido
      // no cabe y el botón de guardar tiene que seguir siendo alcanzable.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agarradera: indica que la hoja se puede arrastrar para cerrar.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Guardar este sitio',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Se guarda el punto donde estás. Así el próximo cliente lo elige '
              'por nombre en vez de buscarlo en el mapa.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _nombre,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del lugar',
                hintText: 'Ej: Droguería La Fe',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<CategoriaLugar>(
              value: _categoria,
              decoration: const InputDecoration(labelText: 'Tipo de lugar'),
              items: [
                for (final c in CategoriaLugar.values)
                  DropdownMenuItem(
                    value: c,
                    child: Text('${c.emoji}  ${c.etiqueta}'),
                  ),
              ],
              onChanged: (c) =>
                  setState(() => _categoria = c ?? CategoriaLugar.comercio),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _referencia,
              decoration: const InputDecoration(
                labelText: 'Referencia (opcional)',
                hintText: 'Ej: segundo piso, portón azul',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Guardar lugar',
              loading: _enviando,
              onPressed: _enviando ? null : _enviar,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Un administrador lo revisa antes de que aparezca en la app de '
              'los clientes.',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

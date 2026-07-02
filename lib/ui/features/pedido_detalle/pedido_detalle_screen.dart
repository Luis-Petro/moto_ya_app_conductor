import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../../data/models/polyline_codec.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../di/locator.dart';
import '../../../domain/models/calificacion.dart';
import '../../../domain/models/pedido.dart';
import '../../core/format/formato.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/star_rating.dart';
import 'pedido_detalle_view_model.dart';

/// Detalle completo de un pedido del historial del conductor: recorrido en mapa,
/// distancia/duración, tarifa y ganancia, direcciones y calificación recibida.
class PedidoDetalleScreen extends StatelessWidget {
  const PedidoDetalleScreen({super.key, required this.pedidoId, this.inicial});

  final int pedidoId;
  final Pedido? inicial;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PedidoDetalleViewModel(
        locator<PedidoRepository>(),
        pedidoId,
        inicial: inicial,
      )..cargar(),
      child: const _DetalleView(),
    );
  }
}

class _DetalleView extends StatelessWidget {
  const _DetalleView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PedidoDetalleViewModel>();
    final p = vm.pedido;
    return Scaffold(
      appBar: AppBar(title: Text(p != null ? 'Pedido #${p.id}' : 'Pedido')),
      body: SafeArea(
        child: p == null
            ? Center(
                child: vm.cargando
                    ? const CircularProgressIndicator()
                    : Text(vm.error ?? 'No se pudo cargar el pedido.'),
              )
            : ListView(
                children: [
                  _Mapa(pedido: p),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Encabezado(pedido: p),
                        const SizedBox(height: AppSpacing.lg),
                        _Recorrido(pedido: p),
                        const SizedBox(height: AppSpacing.lg),
                        _Direcciones(pedido: p),
                        const SizedBox(height: AppSpacing.lg),
                        _Tarifa(pedido: p),
                        const SizedBox(height: AppSpacing.lg),
                        _Calificacion(cargando: vm.cargando, calificacion: vm.calificacion, pedido: p),
                        if (p.motivoCancelacion != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _Motivo(motivo: p.motivoCancelacion!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Mapa extends StatelessWidget {
  const _Mapa({required this.pedido});
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final ruta = PolylineCodec.decode(pedido.rutaPolyline);
    final origen = pedido.origen;
    final destino = pedido.destino;
    // Centra en el trayecto si hay ruta; si no, en el destino/origen disponible.
    final centro = ruta.isNotEmpty
        ? ruta[ruta.length ~/ 2]
        : (destino ?? origen ?? LocationService.fallbackCenter);
    return SizedBox(
      height: 220,
      child: FlutterMap(
        options: MapOptions(initialCenter: centro, initialZoom: 14),
        children: [
          osmTileLayer(),
          if (ruta.length >= 2)
            PolylineLayer(polylines: [
              Polyline(points: ruta, strokeWidth: 4, color: AppColors.primary),
            ]),
          MarkerLayer(markers: [
            if (origen != null)
              pinMarker(origen, icon: Icons.trip_origin, color: AppColors.accent),
            if (destino != null)
              pinMarker(destino, icon: Icons.location_on),
          ]),
          osmAttribution(),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.pedido});
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primarySurface,
          child: Icon(pedido.categoria.icon, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pedido.categoria.label,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text('${pedido.estado.label} · ${Formato.fechaHora(pedido.entregadoEn ?? pedido.creadoEn)}',
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Recorrido extends StatelessWidget {
  const _Recorrido({required this.pedido});
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    return MotoCard(
      child: Row(
        children: [
          Expanded(
            child: _Dato(
              icon: Icons.straighten_rounded,
              etiqueta: 'Distancia',
              valor: Formato.distancia(pedido.distanciaEstimadaMetros),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _Dato(
              icon: Icons.schedule_rounded,
              etiqueta: 'Recorrido',
              valor: Formato.duracion(pedido.duracionEstimadaSegundos),
            ),
          ),
        ],
      ),
    );
  }
}

class _Direcciones extends StatelessWidget {
  const _Direcciones({required this.pedido});
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    return MotoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Punto(
            icon: Icons.trip_origin,
            color: AppColors.accent,
            titulo: 'Recogida',
            texto: pedido.direccionRecogida,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 11),
            child: SizedBox(
              height: 20,
              child: VerticalDivider(width: 2, thickness: 1, color: AppColors.line),
            ),
          ),
          _Punto(
            icon: Icons.location_on,
            color: AppColors.primary,
            titulo: 'Entrega',
            texto: pedido.direccionDestino,
          ),
          if (pedido.descripcion.trim().isNotEmpty) ...[
            const Divider(height: AppSpacing.lg),
            Text(pedido.descripcion,
                style: const TextStyle(color: AppColors.ink, fontSize: 13)),
          ],
          if (pedido.referencia != null && pedido.referencia!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Referencia: ${pedido.referencia}',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _Tarifa extends StatelessWidget {
  const _Tarifa({required this.pedido});
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final tarifa = pedido.tarifaFinal ?? pedido.tarifaSugerida ?? 0;
    final ganancia = Pedido.gananciaNeta(tarifa);
    final comision = Pedido.comision(tarifa);
    return MotoCard(
      child: Column(
        children: [
          _FilaMonto('Tarifa del servicio', Formato.moneda(tarifa)),
          const SizedBox(height: AppSpacing.sm),
          _FilaMonto('Comisión plataforma (15%)', '-${Formato.moneda(comision)}',
              color: AppColors.inkMuted),
          if (pedido.requiereCompra) ...[
            const SizedBox(height: AppSpacing.sm),
            _FilaMonto('Compra a reembolsar (no comisionable)',
                Formato.moneda(pedido.montoCompraEstimado), color: AppColors.inkMuted),
          ],
          const Divider(height: AppSpacing.lg),
          _FilaMonto('Tu ganancia neta', '+${Formato.moneda(ganancia)}',
              destacado: true, color: AppColors.success),
        ],
      ),
    );
  }
}

class _Calificacion extends StatelessWidget {
  const _Calificacion({required this.cargando, required this.calificacion, required this.pedido});
  final bool cargando;
  final Calificacion? calificacion;
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final c = calificacion;
    return MotoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calificación del cliente',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          if (c != null) ...[
            Row(
              children: [
                StarRating(value: c.puntaje.toDouble(), size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('${c.puntaje}.0',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            if (c.tieneComentario) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('"${c.comentario!}"',
                  style: const TextStyle(
                      color: AppColors.inkMuted, fontStyle: FontStyle.italic)),
            ],
          ] else
            Text(
              cargando
                  ? 'Cargando…'
                  : (pedido.estado.esFinal
                      ? 'El cliente aún no te ha calificado.'
                      : 'Disponible cuando se complete el pedido.'),
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

class _Motivo extends StatelessWidget {
  const _Motivo({required this.motivo});
  final String motivo;

  @override
  Widget build(BuildContext context) {
    return MotoCard(
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, color: AppColors.inkMuted, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text('Cancelado: $motivo',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Piezas reutilizables ──

class _Dato extends StatelessWidget {
  const _Dato({required this.icon, required this.etiqueta, required this.valor});
  final IconData icon;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        Text(etiqueta, style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
      ],
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.icon, required this.color, required this.titulo, this.texto});
  final IconData icon;
  final Color color;
  final String titulo;
  final String? texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
              Text(texto == null || texto!.trim().isEmpty ? 'Ubicación en el mapa' : texto!,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaMonto extends StatelessWidget {
  const _FilaMonto(this.etiqueta, this.valor, {this.destacado = false, this.color});
  final String etiqueta;
  final String valor;
  final bool destacado;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final peso = destacado ? FontWeight.w800 : FontWeight.w500;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(etiqueta,
              style: TextStyle(
                  fontWeight: peso, fontSize: destacado ? 15 : 13, color: color ?? AppColors.ink)),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(valor,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: destacado ? 16 : 14,
                color: color ?? AppColors.ink)),
      ],
    );
  }
}

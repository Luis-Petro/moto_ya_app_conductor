import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../di/locator.dart';
import '../../../domain/models/pedido.dart';
import '../../core/format/formato.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/moto_card.dart';
import 'historial_view_model.dart';

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HistorialViewModel(
        locator<PedidoRepository>(),
        locator<ConductorRepository>(),
      )..cargar(),
      child: const _HistorialView(),
    );
  }
}

class _HistorialView extends StatelessWidget {
  const _HistorialView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistorialViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Historial e ingresos')),
      body: SafeArea(
        child: vm.cargando
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: vm.cargar,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _Reputacion(vm: vm),
                    const SizedBox(height: AppSpacing.lg),
                    _Ingresos(vm: vm),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('PEDIDOS RECIENTES',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkMuted,
                            letterSpacing: 0.4)),
                    const SizedBox(height: AppSpacing.sm),
                    if (vm.recientes.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Aún no tienes pedidos',
                        subtitle:
                            'Ponte en línea para recibir tu primer pedido.',
                      )
                    else
                      ...vm.recientes.map((p) => _PedidoTile(pedido: p)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Reputacion extends StatelessWidget {
  const _Reputacion({required this.vm});
  final HistorialViewModel vm;

  @override
  Widget build(BuildContext context) {
    final acept = vm.tasaAceptacion;
    return Row(
      children: [
        Expanded(
          child: _MetricaCard(
            valor: vm.calificacion != null
                ? vm.calificacion!.toStringAsFixed(1)
                : '—',
            etiqueta: 'Calificación',
            icon: Icons.star_rounded,
            iconColor: AppColors.star,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MetricaCard(
            valor: acept != null ? '${(acept * 100).round()}%' : '—',
            etiqueta: 'Aceptación',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MetricaCard(
            valor: '${vm.totalPedidos}',
            etiqueta: 'Pedidos',
          ),
        ),
      ],
    );
  }
}

class _MetricaCard extends StatelessWidget {
  const _MetricaCard({
    required this.valor,
    required this.etiqueta,
    this.icon,
    this.iconColor,
  });
  final String valor;
  final String etiqueta;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return MotoCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 2),
              ],
              Text(valor,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 2),
          Text(etiqueta,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _Ingresos extends StatelessWidget {
  const _Ingresos({required this.vm});
  final HistorialViewModel vm;

  static const _dias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final maxVal = vm.ingresosSemana.fold<double>(0, (a, b) => b > a ? b : a);
    return MotoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ingresos esta semana',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
              Text(Formato.moneda(vm.totalSemana),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final val = vm.ingresosSemana[i];
                final h = maxVal <= 0 ? 0.0 : (val / maxVal) * 96;
                final hoy = DateTime.now().weekday - 1 == i;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: h < 4 ? 4 : h,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: hoy ? AppColors.primary : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(_dias[i],
                          style: const TextStyle(
                              color: AppColors.inkMuted, fontSize: 11)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _PedidoTile extends StatelessWidget {
  const _PedidoTile({required this.pedido});
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final ganancia = Pedido.gananciaNeta(pedido.tarifaFinal ?? pedido.tarifaSugerida ?? 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: MotoCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primarySurface,
              child: Icon(pedido.categoria.icon,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${pedido.categoria.label} · ${pedido.direccionDestino ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(Formato.fechaHora(pedido.entregadoEn),
                      style: const TextStyle(
                          color: AppColors.inkMuted, fontSize: 12)),
                ],
              ),
            ),
            Text('+${Formato.moneda(ganancia)}',
                style: const TextStyle(
                    color: AppColors.success, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

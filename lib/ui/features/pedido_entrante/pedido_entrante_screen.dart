import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/pedido_repository.dart';
import '../../../di/locator.dart';
import '../../../domain/models/pedido.dart';
import '../../core/format/formato.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/primary_button.dart';
import 'pedido_entrante_view_model.dart';

class PedidoEntranteScreen extends StatelessWidget {
  const PedidoEntranteScreen({super.key, required this.pedidoId});
  final int pedidoId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          PedidoEntranteViewModel(locator<PedidoRepository>(), pedidoId)..cargar(),
      child: const _EntranteView(),
    );
  }
}

class _EntranteView extends StatelessWidget {
  const _EntranteView();

  Future<void> _enviar(BuildContext context, PedidoEntranteViewModel vm,
      {required bool aceptarSugerida}) async {
    final ok = await vm.enviarPropuesta(aceptarSugerida: aceptarSugerida);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Propuesta enviada. Te avisamos si el cliente acepta.')),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'No pudimos enviar tu propuesta')),
      );
    }
  }

  Future<void> _rechazar(BuildContext context, PedidoEntranteViewModel vm) async {
    final ok = await vm.rechazar();
    if (!context.mounted) return;
    // Aunque falle el registro, cerramos: el conductor decidió no tomarla.
    if (!ok && vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error!)),
      );
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PedidoEntranteViewModel>();

    if (vm.estado == EstadoEntrante.cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (vm.estado == EstadoEntrante.error) {
      return Scaffold(
        body: SafeArea(
          child: ErrorRetry(
              message: vm.error ?? 'No pudimos cargar el pedido',
              onRetry: vm.cargar),
        ),
      );
    }

    final pedido = vm.pedido!;
    final expirado = vm.estado == EstadoEntrante.expirado;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _CabeceraNuevo(segundos: vm.segundosRestantes, expirado: expirado),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Row(
                    children: [
                      Icon(pedido.categoria.icon,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(pedido.categoria.label,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      const Icon(Icons.navigation_outlined,
                          size: 15, color: AppColors.inkMuted),
                      const SizedBox(width: 2),
                      Text('#${pedido.id}',
                          style: const TextStyle(
                              color: AppColors.inkMuted, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  MotoCard(
                    child: Column(
                      children: [
                        _PuntoRuta(
                          icon: Icons.circle_outlined,
                          titulo: 'Recoger',
                          detalle: pedido.direccionRecogida ??
                              pedido.descripcion,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Divider(height: 1),
                        ),
                        _PuntoRuta(
                          icon: Icons.location_on_outlined,
                          titulo: 'Entregar',
                          detalle: pedido.direccionDestino ?? '—',
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _RecorridoYDetalle(pedido: pedido),
                  const SizedBox(height: AppSpacing.md),
                  _Desglose(vm: vm),
                  const SizedBox(height: AppSpacing.md),
                  _ProponerTarifa(vm: vm),
                ],
              ),
            ),
            _Acciones(
                vm: vm,
                onEnviar: _enviar,
                onRechazar: _rechazar,
                expirado: expirado),
          ],
        ),
      ),
    );
  }
}

class _CabeceraNuevo extends StatelessWidget {
  const _CabeceraNuevo({required this.segundos, required this.expirado});
  final int segundos;
  final bool expirado;

  @override
  Widget build(BuildContext context) {
    final mm = (segundos ~/ 60).toString();
    final ss = (segundos % 60).toString().padLeft(2, '0');
    return Container(
      width: double.infinity,
      color: AppColors.accent,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        children: [
          const Text('¡Nuevo pedido!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  expirado ? 'Oferta expirada' : 'Responde en $mm:$ss',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PuntoRuta extends StatelessWidget {
  const _PuntoRuta({
    required this.icon,
    required this.titulo,
    required this.detalle,
    this.color = AppColors.inkMuted,
  });
  final IconData icon;
  final String titulo;
  final String detalle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              Text(detalle,
                  style:
                      const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Distancia y tiempo estimados, mensaje completo del mandado y monto de compra
/// (si el pedido requiere adelantar dinero).
class _RecorridoYDetalle extends StatelessWidget {
  const _RecorridoYDetalle({required this.pedido});
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    return MotoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(Formato.distancia(pedido.distanciaEstimadaMetros),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: AppSpacing.lg),
              const Icon(Icons.schedule_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(Formato.duracion(pedido.duracionEstimadaSegundos),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          if (pedido.descripcion.trim().isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            const Text('Detalle del mandado',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted)),
            const SizedBox(height: 2),
            Text(pedido.descripcion,
                style: const TextStyle(fontSize: 14)),
          ],
          if (pedido.requiereCompra) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      pedido.montoCompraEstimado != null
                          ? 'Debes adelantar ~${Formato.moneda(pedido.montoCompraEstimado)} para la compra (el cliente te lo reembolsa).'
                          : 'Este pedido requiere que adelantes la compra (el cliente te la reembolsa).',
                      style: const TextStyle(fontSize: 13, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Desglose extends StatelessWidget {
  const _Desglose({required this.vm});
  final PedidoEntranteViewModel vm;

  @override
  Widget build(BuildContext context) {
    return MotoCard(
      color: AppColors.primarySurface,
      child: Column(
        children: [
          _Fila(label: 'Tarifa sugerida', valor: Formato.moneda(vm.montoPropuesto)),
          const SizedBox(height: 6),
          _Fila(
            label: 'Comisión plataforma (15%)',
            valor: '-${Formato.moneda(vm.comision)}',
            valorColor: AppColors.danger,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _Fila(
            label: 'Ganancia neta',
            valor: Formato.moneda(vm.gananciaNeta),
            bold: true,
            valorColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.label,
    required this.valor,
    this.bold = false,
    this.valorColor,
  });
  final String label;
  final String valor;
  final bool bold;
  final Color? valorColor;

  @override
  Widget build(BuildContext context) {
    final peso = bold ? FontWeight.w800 : FontWeight.w500;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: peso, fontSize: 14)),
        Text(valor,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: bold ? 18 : 14,
                color: valorColor ?? AppColors.ink)),
      ],
    );
  }
}

class _ProponerTarifa extends StatelessWidget {
  const _ProponerTarifa({required this.vm});
  final PedidoEntranteViewModel vm;

  @override
  Widget build(BuildContext context) {
    return MotoCard(
      child: Row(
        children: [
          const Expanded(
            child: Text('Proponer otra tarifa',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            onPressed: () => vm.ajustarMonto(-500),
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.primary,
          ),
          Text(Formato.moneda(vm.montoPropuesto),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16)),
          IconButton(
            onPressed: () => vm.ajustarMonto(500),
            icon: const Icon(Icons.add_circle),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({
    required this.vm,
    required this.onEnviar,
    required this.onRechazar,
    required this.expirado,
  });
  final PedidoEntranteViewModel vm;
  final Future<void> Function(BuildContext, PedidoEntranteViewModel,
      {required bool aceptarSugerida}) onEnviar;
  final Future<void> Function(BuildContext, PedidoEntranteViewModel) onRechazar;
  final bool expirado;

  @override
  Widget build(BuildContext context) {
    if (expirado) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: OutlinedButton(
          onPressed: () => context.pop(),
          child: const Text('Volver'),
        ),
      );
    }
    final contra = vm.esContraoferta;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed:
                  (vm.enviando || vm.rechazando) ? null : () => onRechazar(context, vm),
              child: vm.rechazando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Rechazar'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: contra
                  ? 'Proponer ${Formato.moneda(vm.montoPropuesto)}'
                  : 'Aceptar ${Formato.moneda(vm.tarifaSugerida)}',
              loading: vm.enviando,
              onPressed: () => onEnviar(context, vm, aceptarSugerida: !contra),
            ),
          ),
        ],
      ),
    );
  }
}

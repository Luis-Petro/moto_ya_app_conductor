import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/billetera_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../di/locator.dart';
import '../../../domain/models/billetera.dart';
import '../../core/format/formato.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/primary_button.dart';
import 'billetera_view_model.dart';

class BilleteraScreen extends StatelessWidget {
  const BilleteraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BilleteraViewModel(
        locator<BilleteraRepository>(),
        locator<ConductorRepository>(),
      )..cargar(),
      child: const _BilleteraView(),
    );
  }
}

class _BilleteraView extends StatelessWidget {
  const _BilleteraView();

  Future<void> _pagar(BuildContext context, BilleteraViewModel vm) async {
    final ok = await vm.pagarDeuda();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? (vm.aviso ?? 'Pago iniciado') : (vm.error ?? 'No pudimos iniciar el pago'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BilleteraViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Billetera')),
      body: SafeArea(
        child: vm.cargando
            ? const Center(child: CircularProgressIndicator())
            : vm.billetera == null
                ? ErrorRetry(
                    message: vm.error ?? 'No pudimos cargar tu billetera',
                    onRetry: vm.cargar)
                : RefreshIndicator(
                    onRefresh: vm.cargar,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        if (vm.bloqueado) const _BannerBloqueo(),
                        _TarjetaDeuda(billetera: vm.billetera!),
                        const SizedBox(height: AppSpacing.lg),
                        _EstadoCuenta(bloqueado: vm.bloqueado),
                        const SizedBox(height: AppSpacing.xl),
                        const Text('PAGAR CON',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkMuted,
                                letterSpacing: 0.4)),
                        const SizedBox(height: AppSpacing.sm),
                        _Medios(vm: vm),
                        const SizedBox(height: AppSpacing.xl),
                        PrimaryButton(
                          label: vm.bloqueado
                              ? 'Pagar ${Formato.moneda(vm.billetera!.deudaActual)} y reactivar'
                              : 'Pagar deuda',
                          icon: Icons.lock_open_rounded,
                          loading: vm.pagando,
                          onPressed: vm.billetera!.deudaActual <= 0
                              ? null
                              : () => _pagar(context, vm),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _BannerBloqueo extends StatelessWidget {
  const _BannerBloqueo();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: AppColors.danger, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Cuenta bloqueada por deuda',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _TarjetaDeuda extends StatelessWidget {
  const _TarjetaDeuda({required this.billetera});
  final Billetera billetera;

  @override
  Widget build(BuildContext context) {
    final frac = billetera.fraccionUso.clamp(0.0, 1.0);
    final color = billetera.bloqueado
        ? AppColors.danger
        : (frac > 0.8 ? AppColors.warning : AppColors.success);
    return MotoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: AppColors.inkMuted),
              const SizedBox(width: 6),
              const Text('Comisiones pendientes',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Text(Formato.moneda(billetera.deudaActual),
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: billetera.bloqueado ? AppColors.danger : AppColors.ink)),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor: AppColors.line,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${billetera.porcentajeUso}% del límite',
                  style:
                      const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
              Text('Límite ${Formato.moneda(billetera.limite)}',
                  style:
                      const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EstadoCuenta extends StatelessWidget {
  const _EstadoCuenta({required this.bloqueado});
  final bool bloqueado;

  @override
  Widget build(BuildContext context) {
    final color = bloqueado ? AppColors.danger : AppColors.success;
    final surface = bloqueado ? AppColors.dangerSurface : const Color(0xFFEAF7F1);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Icon(bloqueado ? Icons.block : Icons.check_circle,
              color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              bloqueado
                  ? 'No puedes recibir pedidos. Paga para reactivar tu cuenta.'
                  : 'Cuenta al día. Sigue recibiendo pedidos con normalidad.',
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Medios extends StatelessWidget {
  const _Medios({required this.vm});
  final BilleteraViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MedioChip(vm: vm, medio: MedioPago.nequi, icon: 'N')),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _MedioChip(vm: vm, medio: MedioPago.breB, icon: 'B')),
      ],
    );
  }
}

class _MedioChip extends StatelessWidget {
  const _MedioChip({required this.vm, required this.medio, required this.icon});
  final BilleteraViewModel vm;
  final MedioPago medio;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final sel = vm.medioSeleccionado == medio;
    return InkWell(
      onTap: () => vm.seleccionarMedio(medio),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: sel ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: sel ? AppColors.primary : AppColors.line,
            width: sel ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: sel ? AppColors.primary : AppColors.accentSurface,
              child: Text(icon,
                  style: TextStyle(
                      color: sel ? Colors.white : AppColors.accent,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            Text(medio.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

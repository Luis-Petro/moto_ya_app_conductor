import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/billetera_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../di/locator.dart';
import '../../../domain/models/billetera.dart';
import '../../core/format/formato.dart';
import '../../core/tab_activa.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/primary_button.dart';
import 'billetera_view_model.dart';

/// Colores de marca de los medios de pago (identidad visual reconocible).
const _colorNequi = Color(0xFFDA0081);
const _colorBreB = Color(0xFFF2C500);

class BilleteraScreen extends StatelessWidget {
  const BilleteraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BilleteraViewModel(
        locator<BilleteraRepository>(),
        locator<ConductorRepository>(),
        locator<TabActiva>(),
      )..cargar(),
      child: const _BilleteraView(),
    );
  }
}

class _BilleteraView extends StatefulWidget {
  const _BilleteraView();

  @override
  State<_BilleteraView> createState() => _BilleteraViewState();
}

class _BilleteraViewState extends State<_BilleteraView> {
  final _monto = TextEditingController();
  bool _montoInicializado = false;

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  /// Prefija el monto con la deuda actual la primera vez que hay datos.
  void _prefijarMonto(BilleteraViewModel vm) {
    if (_montoInicializado || vm.billetera == null) return;
    _montoInicializado = true;
    final deuda = vm.billetera!.deudaActual;
    _monto.text = deuda > 0 ? deuda.round().toString() : '';
  }

  double get _montoIngresado =>
      double.tryParse(_monto.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;

  Future<void> _pagar(BuildContext context, BilleteraViewModel vm) async {
    final ok = await vm.pagar(_montoIngresado);
    if (!context.mounted) return;
    if (ok && vm.intencion != null) {
      await _mostrarTransaccion(context, vm.intencion!);
    } else if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'No pudimos iniciar el pago')),
      );
    }
  }

  /// Ficha de la transacción iniciada: monto, medio, referencia y siguiente paso.
  Future<void> _mostrarTransaccion(
      BuildContext context, IntencionPago intencion) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => _TransaccionSheet(intencion: intencion),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BilleteraViewModel>();
    _prefijarMonto(vm);
    final b = vm.billetera;
    return Scaffold(
      appBar: AppBar(title: const Text('Billetera')),
      body: SafeArea(
        child: vm.cargando && b == null
            ? const Center(child: CircularProgressIndicator())
            : b == null
                ? ErrorRetry(
                    message: vm.error ?? 'No pudimos cargar tu billetera',
                    onRetry: vm.cargar)
                : RefreshIndicator(
                    onRefresh: vm.cargar,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        if (vm.bloqueado) const _BannerBloqueo(),
                        _TarjetaSaldo(billetera: b),
                        const SizedBox(height: AppSpacing.lg),
                        _EstadoCuenta(billetera: b),
                        if (vm.intencion != null &&
                            vm.intencion!.pendiente) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _PagoEnProceso(
                            intencion: vm.intencion!,
                            onVer: () =>
                                _mostrarTransaccion(context, vm.intencion!),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        const Text('PAGAR CON',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkMuted,
                                letterSpacing: 0.4)),
                        const SizedBox(height: AppSpacing.sm),
                        _Medios(vm: vm),
                        const SizedBox(height: AppSpacing.lg),
                        const Text('MONTO A PAGAR',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkMuted,
                                letterSpacing: 0.4)),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _monto,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixText: r'$ ',
                            hintText: b.enDeuda
                                ? b.deudaActual.round().toString()
                                : 'Monto a abonar',
                            helperText: b.enDeuda
                                ? 'Puedes pagar más que la deuda: el resto queda como saldo a favor.'
                                : 'Lo que abones queda como saldo a favor para tus próximas comisiones.',
                            helperMaxLines: 2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        PrimaryButton(
                          label: vm.bloqueado
                              ? 'Pagar ${Formato.moneda(_montoIngresado)} y reactivar'
                              : (b.enDeuda
                                  ? 'Pagar ${Formato.moneda(_montoIngresado)}'
                                  : 'Abonar ${Formato.moneda(_montoIngresado)}'),
                          icon: b.enDeuda
                              ? Icons.lock_open_rounded
                              : Icons.savings_outlined,
                          loading: vm.pagando,
                          onPressed: _montoIngresado <= 0
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

/// Tarjeta principal: deuda pendiente o saldo a favor, con barra de uso del
/// límite cuando hay deuda.
class _TarjetaSaldo extends StatelessWidget {
  const _TarjetaSaldo({required this.billetera});
  final Billetera billetera;

  @override
  Widget build(BuildContext context) {
    final aFavor = billetera.saldoAFavor > 0;
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
              Icon(
                  aFavor
                      ? Icons.savings_outlined
                      : Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: AppColors.inkMuted),
              const SizedBox(width: 6),
              Text(aFavor ? 'Saldo a favor' : 'Comisiones pendientes',
                  style: const TextStyle(
                      color: AppColors.inkMuted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              Formato.moneda(
                  aFavor ? billetera.saldoAFavor : billetera.deudaActual),
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: billetera.bloqueado
                      ? AppColors.danger
                      : (aFavor ? AppColors.success : AppColors.ink))),
          if (aFavor) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Tus próximas comisiones se descuentan de este saldo antes de generar deuda.',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
            ),
          ] else ...[
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
                    style: const TextStyle(
                        color: AppColors.inkMuted, fontSize: 12)),
                Text('Límite ${Formato.moneda(billetera.limite)}',
                    style: const TextStyle(
                        color: AppColors.inkMuted, fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EstadoCuenta extends StatelessWidget {
  const _EstadoCuenta({required this.billetera});
  final Billetera billetera;

  @override
  Widget build(BuildContext context) {
    final bloqueado = billetera.bloqueado;
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

/// Aviso de pago iniciado pendiente de confirmación, con acceso a su detalle.
class _PagoEnProceso extends StatelessWidget {
  const _PagoEnProceso({required this.intencion, required this.onVer});
  final IntencionPago intencion;
  final VoidCallback onVer;

  @override
  Widget build(BuildContext context) {
    return MotoCard(
      onTap: onVer,
      color: AppColors.accentSurface,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Pago de ${Formato.moneda(intencion.monto)} por ${intencion.medioPago.label} en proceso',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const Text('Ver',
              style: TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w700)),
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
        Expanded(
          child: _MedioChip(
            vm: vm,
            medio: MedioPago.nequi,
            marca: _colorNequi,
            letra: 'N',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MedioChip(
            vm: vm,
            medio: MedioPago.breB,
            marca: _colorBreB,
            letra: 'B',
            letraOscura: true,
          ),
        ),
      ],
    );
  }
}

/// Chip de medio de pago con el color de marca del proveedor.
class _MedioChip extends StatelessWidget {
  const _MedioChip({
    required this.vm,
    required this.medio,
    required this.marca,
    required this.letra,
    this.letraOscura = false,
  });
  final BilleteraViewModel vm;
  final MedioPago medio;
  final Color marca;
  final String letra;
  final bool letraOscura;

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
              backgroundColor: marca,
              child: Text(letra,
                  style: TextStyle(
                      color: letraOscura ? AppColors.ink : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
            ),
            const SizedBox(height: 6),
            Text(medio.label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (sel)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.check_circle,
                    size: 16, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

/// Detalle de la transacción iniciada: monto, medio, referencia, estado y
/// siguiente paso (enlace del proveedor si existe).
class _TransaccionSheet extends StatelessWidget {
  const _TransaccionSheet({required this.intencion});
  final IntencionPago intencion;

  Future<void> _abrirEnlace(BuildContext context) async {
    final url = intencion.urlPago;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final esNequi = intencion.medioPago == MedioPago.nequi;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: esNequi ? _colorNequi : _colorBreB,
                  child: Text(esNequi ? 'N' : 'B',
                      style: TextStyle(
                          color: esNequi ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text('Pago por ${intencion.medioPago.label}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _DatoFila(label: 'Monto', valor: Formato.moneda(intencion.monto)),
            _DatoFila(
                label: 'Estado',
                valor: intencion.pendiente
                    ? 'Pendiente de confirmación'
                    : intencion.estado),
            if (intencion.referenciaExterna != null)
              _DatoFila(
                  label: 'Referencia', valor: intencion.referenciaExterna!),
            if (intencion.instrucciones != null &&
                intencion.instrucciones!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(intencion.instrucciones!,
                    style: const TextStyle(fontSize: 13, height: 1.35)),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Cuando el pago se confirme, tu saldo y tu cuenta se actualizan solos.',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (intencion.urlPago != null)
              PrimaryButton(
                label: 'Completar el pago',
                icon: Icons.open_in_new_rounded,
                onPressed: () => _abrirEnlace(context),
              )
            else
              PrimaryButton(
                label: 'Entendido',
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

class _DatoFila extends StatelessWidget {
  const _DatoFila({required this.label, required this.valor});
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.inkMuted)),
          const Spacer(),
          Flexible(
            child: Text(valor,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

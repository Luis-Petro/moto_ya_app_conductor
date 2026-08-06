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

/// Logos oficiales de los medios de pago (identidad visual reconocible).
const _logoNequi = 'assets/images/nequi.png';
const _logoBreB = 'assets/images/breb.png';

String _logoMedio(MedioPago medio) =>
    medio == MedioPago.nequi ? _logoNequi : _logoBreB;

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

  /// Único dato que se le pide al conductor para conciliar: a nombre de quién
  /// salió la transferencia. El número de cuenta lo aportaba a mano y llegaba
  /// mal tecleado la mitad de las veces; para cruzar el movimiento basta el
  /// nombre del titular, el monto y la hora.
  final _titularOrigen = TextEditingController();
  bool _montoInicializado = false;

  final _scroll = ScrollController();

  @override
  void dispose() {
    _monto.dispose();
    _titularOrigen.dispose();
    _scroll.dispose();
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
    if (_titularOrigen.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Escribe a nombre de quién enviaste la transferencia')));
      return;
    }
    final ok = await vm.pagar(
      _montoIngresado,
      titularOrigen: _titularOrigen.text.trim(),
    );
    if (!context.mounted) return;
    if (ok && vm.intencion != null) {
      // El pago ya quedó registrado: el formulario se vacía para que nadie
      // reenvíe el mismo abono de un segundo toque.
      _monto.clear();
      _titularOrigen.clear();
      FocusScope.of(context).unfocus();
      if (mounted) setState(() {});
      if (!context.mounted) return;
      await _mostrarTransaccion(context, vm.intencion!);
      _irAlEstado();
    } else if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'No pudimos iniciar el pago')),
      );
    }
  }

  /// Sube al principio tras pagar. El formulario queda al final de la pantalla
  /// y, sin esto, el conductor se quedaba mirando el botón vacío sin ver que su
  /// pago quedó registrado y en revisión.
  void _irAlEstado() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(0,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  /// Historial completo en una hoja: se consulta de vez en cuando (una duda,
  /// un reclamo), no en cada pago.
  Future<void> _verHistorial(BuildContext context, List<PagoRealizado> pagos) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HistorialSheet(pagos: pagos),
    );
  }

  /// Ficha de la transacción iniciada: monto, destino, referencia y siguiente paso.
  Future<void> _mostrarTransaccion(
      BuildContext context, IntencionPago intencion) {
    final datos = context.read<BilleteraViewModel>().datosPago;
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => _TransaccionSheet(intencion: intencion, datos: datos),
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
                      controller: _scroll,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        if (vm.bloqueado) const _BannerBloqueo(),
                        _TarjetaSaldo(billetera: b),
                        const SizedBox(height: AppSpacing.lg),
                        _EstadoCuenta(billetera: b),
                        // El pago en proceso viene del servidor: sobrevive al
                        // cambio de pestaña y al reinicio de la app.
                        if (vm.pagoPendiente != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _PagoEnProceso(
                            pago: vm.pagoPendiente!,
                            onVer: vm.intencion == null
                                ? null
                                : () =>
                                    _mostrarTransaccion(context, vm.intencion!),
                          ),
                        ] else if (vm.aviso != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _PagoConfirmado(
                            mensaje: vm.aviso!,
                            onCerrar: vm.descartarIntencion,
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
                        if (vm.datosPago != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _DestinoPago(
                              datos: vm.datosPago!, medio: vm.medioSeleccionado),
                        ],
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
                        const SizedBox(height: AppSpacing.lg),
                        const Text('¿QUIÉN ENVÍA LA TRANSFERENCIA?',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkMuted,
                                letterSpacing: 0.4)),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _titularOrigen,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.person_outline),
                            hintText: 'Nombre de quien envía',
                            helperText:
                                'Con el nombre, el monto y la hora cruzamos tu pago.',
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
                          onPressed: (_montoIngresado <= 0 ||
                                  _titularOrigen.text.trim().isEmpty)
                              ? null
                              : () => _pagar(context, vm),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        // El historial no vive en la pantalla principal: es
                        // consulta ocasional y empujaba el formulario de pago
                        // (lo que el conductor viene a hacer) fuera de vista.
                        _AccesoHistorial(
                          pagos: vm.pagos,
                          onVer: () => _verHistorial(context, vm.pagos),
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
    final surface = bloqueado ? AppColors.dangerSurface : AppColors.successSurface;
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

/// Pago registrado y pendiente de confirmación, con acceso a su detalle si
/// todavía tenemos las instrucciones del proveedor en esta sesión.
class _PagoEnProceso extends StatelessWidget {
  const _PagoEnProceso({required this.pago, this.onVer});
  final PagoRealizado pago;
  final VoidCallback? onVer;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pago de ${Formato.moneda(pago.valor)} por ${pago.medioPago.label} en revisión',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Text(
                  'Lo confirmamos al verificar la transferencia.',
                  style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          if (onVer != null)
            const Text('Ver',
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Entrada al historial: una fila discreta con el último pago como referencia.
///
/// Sin ella, un pago confirmado ayer no dejaba rastro en la app y la única
/// prueba de haber pagado era el comprobante del banco.
class _AccesoHistorial extends StatelessWidget {
  const _AccesoHistorial({required this.pagos, required this.onVer});
  final List<PagoRealizado> pagos;
  final VoidCallback onVer;

  @override
  Widget build(BuildContext context) {
    if (pagos.isEmpty) {
      return const MotoCard(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Text('Aún no has registrado pagos de comisión.',
            style: TextStyle(fontSize: 13, color: AppColors.inkMuted)),
      );
    }
    final ultimo = pagos.first;
    return MotoCard(
      onTap: onVer,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 20, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mis pagos',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  'Último: ${Formato.moneda(ultimo.valor)} · ${ultimo.estadoLabel.toLowerCase()}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}

/// Historial completo de pagos, en hoja inferior.
class _HistorialSheet extends StatelessWidget {
  const _HistorialSheet({required this.pagos});
  final List<PagoRealizado> pagos;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scroll) => Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          const Text('Mis pagos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView.separated(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
              itemCount: pagos.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _FilaPago(pago: pagos[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaPago extends StatelessWidget {
  const _FilaPago({required this.pago});
  final PagoRealizado pago;

  @override
  Widget build(BuildContext context) {
    final (color, icono) = pago.confirmado
        ? (AppColors.success, Icons.check_circle_outline)
        : pago.fallido
            ? (AppColors.danger, Icons.error_outline)
            : (AppColors.accent, Icons.schedule_rounded);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Formato.moneda(pago.valor),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${pago.medioPago.label} · ${Formato.fechaHora(pago.confirmadoEn ?? pago.creadoEn)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          Text(pago.estadoLabel,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Aviso de pago confirmado (el saldo/estado ya se actualizaron), descartable.
class _PagoConfirmado extends StatelessWidget {
  const _PagoConfirmado({required this.mensaje, required this.onCerrar});
  final String mensaje;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(mensaje,
                style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          InkWell(
            onTap: onCerrar,
            child: const Icon(Icons.close_rounded,
                color: AppColors.success, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Datos de destino a donde transferir según el medio seleccionado (Nequi/Bre-B),
/// administrados desde el panel. Si no hay datos configurados, avisa.
///
/// El número se puede copiar de un toque: el conductor tiene que salir a la app
/// del banco para transferir, y memorizar diez dígitos entre una app y otra es
/// donde se pierden y se equivocan de cuenta.
class _DestinoPago extends StatelessWidget {
  const _DestinoPago({required this.datos, required this.medio});
  final DatosPago datos;
  final MedioPago medio;

  Future<void> _copiar(BuildContext context, String valor) async {
    await Clipboard.setData(ClipboardData(text: valor));
    await HapticFeedback.selectionClick();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Número copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esNequi = medio == MedioPago.nequi;
    final tiene = datos.tieneDatos(medio);
    final destino = esNequi ? datos.nequiNumero : datos.brebLlave;
    final titularRaw = esNequi ? datos.nequiTitular : datos.brebTitular;
    final titular =
        (titularRaw?.trim().isNotEmpty ?? false) ? titularRaw!.trim() : null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.south_east_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: tiene
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transfiere a ${esNequi ? 'Nequi' : 'Bre-B'}:',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkMuted)),
                      const SizedBox(height: 2),
                      Text(
                        destino!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      // El titular va con el mismo peso que el número: es lo
                      // que el conductor coteja en la app del banco antes de
                      // aceptar, y en letra chica se lo salta.
                      Text(
                        titular ?? 'Titular sin configurar',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: titular == null
                              ? AppColors.danger
                              : AppColors.ink,
                        ),
                      ),
                      if (titular == null)
                        const Text(
                          'El administrador aún no registró a nombre de quién '
                          'está la cuenta. Confírmalo antes de transferir.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.danger),
                        ),
                      if (!esNequi &&
                          (datos.brebEntidad?.trim().isNotEmpty ?? false))
                        Text(datos.brebEntidad!,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.inkMuted)),
                    ],
                  )
                : Text(
                    'Aún no hay una cuenta ${esNequi ? 'Nequi' : 'Bre-B'} configurada. Contacta al administrador.',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.inkMuted),
                  ),
          ),
          if (tiene)
            TextButton.icon(
              onPressed: () => _copiar(context, destino!),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.minTouchTarget),
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
        Expanded(child: _MedioChip(vm: vm, medio: MedioPago.nequi)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _MedioChip(vm: vm, medio: MedioPago.breB)),
      ],
    );
  }
}

/// Chip de medio de pago con el logo oficial del proveedor.
class _MedioChip extends StatelessWidget {
  const _MedioChip({required this.vm, required this.medio});
  final BilleteraViewModel vm;
  final MedioPago medio;

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
            // Alto uniforme para ambos logos, sin recorte (BoxFit.contain).
            SizedBox(
              height: 40,
              child: Image.asset(_logoMedio(medio), fit: BoxFit.contain),
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
  const _TransaccionSheet({required this.intencion, this.datos});
  final IntencionPago intencion;

  /// Datos de destino, para repetir aquí a nombre de quién está la cuenta: es
  /// el dato que el conductor coteja en la app del banco al transferir.
  final DatosPago? datos;

  bool get _esNequi => intencion.medioPago == MedioPago.nequi;

  String? get _destino {
    final v = _esNequi ? datos?.nequiNumero : datos?.brebLlave;
    return (v?.trim().isNotEmpty ?? false) ? v!.trim() : null;
  }

  String? get _titular {
    final v = _esNequi ? datos?.nequiTitular : datos?.brebTitular;
    return (v?.trim().isNotEmpty ?? false) ? v!.trim() : null;
  }

  Future<void> _abrirEnlace(BuildContext context) async {
    final url = intencion.urlPago;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
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
                SizedBox(
                  height: 36,
                  width: 36,
                  child: Image.asset(_logoMedio(intencion.medioPago),
                      fit: BoxFit.contain),
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
                label: 'Transfiere a',
                valor: _destino ?? 'Sin configurar'),
            _DatoFila(
                label: 'A nombre de',
                valor: _titular ?? 'Sin configurar (confírmalo antes de enviar)'),
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

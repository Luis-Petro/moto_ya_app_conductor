import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
  /// El formulario de transferencia vive en una hoja aparte: en la pantalla
  /// principal empujaba el saldo y el estado de la cuenta fuera de vista, y el
  /// conductor entra aquí sobre todo a mirar cuánto debe.
  Future<void> _abrirPago(
    BuildContext context,
    BilleteraViewModel vm,
    Billetera billetera,
  ) async {
    final registrado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // La billetera vive en una tab: la hoja se abre sobre su navigator (que es
      // el default de showModalBottomSheet) y necesita el vm pasado a mano.
      builder: (_) => ChangeNotifierProvider<BilleteraViewModel>.value(
        value: vm,
        child: _PagoSheet(billetera: billetera),
      ),
    );
    if (registrado == true && vm.intencion != null && context.mounted) {
      await _mostrarTransaccion(context, vm.intencion!);
    }
  }

  /// Historial completo en una hoja: se consulta de vez en cuando (una duda,
  /// un reclamo), no en cada pago.
  Future<void> _verHistorial(
    BuildContext context,
    List<PagoRealizado> pagos,
    List<MovimientoSaldo> movimientos,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HistorialSheet(pagos: pagos, movimientos: movimientos),
    );
  }

  /// Ficha de la transacción iniciada: monto, destino, referencia y siguiente paso.
  Future<void> _mostrarTransaccion(
    BuildContext context,
    IntencionPago intencion,
  ) {
    final datos = context.read<BilleteraViewModel>().datosPago;
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => _TransaccionSheet(intencion: intencion, datos: datos),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BilleteraViewModel>();
    final b = vm.billetera;
    return Scaffold(
      appBar: AppBar(title: const Text('Billetera')),
      body: SafeArea(
        child: vm.cargando && b == null
            ? const Center(child: CircularProgressIndicator())
            : b == null
            ? ErrorRetry(
                message: vm.error ?? 'No pudimos cargar tu billetera',
                onRetry: vm.cargar,
              )
            : RefreshIndicator(
                onRefresh: vm.cargar,
                child: ListView(
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
                            : () => _mostrarTransaccion(context, vm.intencion!),
                      ),
                    ] else if (vm.aviso != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _PagoConfirmado(
                        mensaje: vm.aviso!,
                        onCerrar: vm.descartarIntencion,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: vm.bloqueado
                          ? 'Pagar y reactivar mi cuenta'
                          : (b.enDeuda
                                ? 'Registrar un pago'
                                : 'Abonar a mi saldo'),
                      icon: b.enDeuda
                          ? Icons.lock_open_rounded
                          : Icons.savings_outlined,
                      onPressed: () => _abrirPago(context, vm, b),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // El historial no vive en la pantalla principal: es
                    // consulta ocasional y empujaba el formulario de pago
                    // (lo que el conductor viene a hacer) fuera de vista.
                    _AccesoHistorial(
                      pagos: vm.pagos,
                      onVer: () =>
                          _verHistorial(context, vm.pagos, vm.movimientos),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Formulario de transferencia en hoja inferior: medio, cuenta de destino, monto
/// y quién envía. Devuelve `true` por el `pop` cuando el pago quedó registrado.
class _PagoSheet extends StatefulWidget {
  const _PagoSheet({required this.billetera});
  final Billetera billetera;

  @override
  State<_PagoSheet> createState() => _PagoSheetState();
}

class _PagoSheetState extends State<_PagoSheet> {
  late final TextEditingController _monto = TextEditingController(
    // Prefijado con la deuda: es lo que el conductor va a pagar 9 de cada 10 veces.
    text: widget.billetera.deudaActual > 0
        ? widget.billetera.deudaActual.round().toString()
        : '',
  );

  /// A nombre de quién salió la transferencia. El número de cuenta lo aportaba
  /// a mano y llegaba mal tecleado la mitad de las veces; para cruzar el
  /// movimiento basta el nombre del titular, el monto y la hora.
  final _titularOrigen = TextEditingController();

  /// Nombre del corresponsal o punto físico donde consignó (solo si no envió
  /// desde su propia cuenta). Va como `entidadOrigen`.
  final _corresponsal = TextEditingController();

  /// El pago salió de un corresponsal/punto físico, no de una cuenta propia.
  /// Cambia por completo qué nombre aparece en el movimiento del banco, y sin
  /// distinguirlo el admin buscaba un titular que nunca iba a encontrar.
  bool _porCorresponsal = false;

  @override
  void dispose() {
    _monto.dispose();
    _titularOrigen.dispose();
    _corresponsal.dispose();
    super.dispose();
  }

  double get _montoIngresado =>
      double.tryParse(_monto.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;

  bool get _datosCompletos =>
      _montoIngresado > 0 &&
      _titularOrigen.text.trim().isNotEmpty &&
      (!_porCorresponsal || _corresponsal.text.trim().isNotEmpty);

  Future<void> _pagar(BilleteraViewModel vm) async {
    final ok = await vm.pagar(
      _montoIngresado,
      titularOrigen: _titularOrigen.text.trim(),
      entidadOrigen: _porCorresponsal ? _corresponsal.text.trim() : null,
    );
    if (!mounted) return;
    if (ok && vm.intencion != null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'No pudimos iniciar el pago')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BilleteraViewModel>();
    final b = widget.billetera;
    return Padding(
      // Sin esto el teclado tapa el campo del monto.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          // Todo el formulario cabe sin scroll: el conductor lo llena con el
          // celular en una mano, saliendo y entrando de la app del banco, y
          // cada campo que quedaba debajo del pliegue era uno que no se llenaba.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                b.enDeuda ? 'Pagar comisiones' : 'Abonar a mi saldo',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _Etiqueta('PAGAR CON'),
              const SizedBox(height: AppSpacing.xs),
              _Medios(vm: vm),
              if (vm.datosPago != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _DestinoPago(datos: vm.datosPago!, medio: vm.medioSeleccionado),
              ],
              const SizedBox(height: AppSpacing.md),
              const _Etiqueta('MONTO A PAGAR'),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _monto,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: r'$ ',
                  hintText: b.enDeuda
                      ? b.deudaActual.round().toString()
                      : 'Monto a abonar',
                  helperText: b.enDeuda
                      ? 'Si pagas de más, el resto queda a tu favor.'
                      : 'Queda a tu favor para tus próximas comisiones.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _Etiqueta('¿DESDE DÓNDE ENVÍAS?'),
              const SizedBox(height: AppSpacing.xs),
              // El nombre que llega al extracto no es el mismo si el conductor
              // transfiere desde su cuenta que si consigna en un corresponsal:
              // en el segundo caso el movimiento sale a nombre del punto y el
              // admin buscaba un titular que nunca iba a aparecer.
              Row(
                children: [
                  Expanded(
                    child: _OrigenChip(
                      icono: Icons.account_balance_wallet_outlined,
                      titulo: 'Mi cuenta',
                      seleccionado: !_porCorresponsal,
                      onTap: () => setState(() => _porCorresponsal = false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _OrigenChip(
                      icono: Icons.storefront_outlined,
                      titulo: 'Corresponsal',
                      seleccionado: _porCorresponsal,
                      onTap: () => setState(() => _porCorresponsal = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _titularOrigen,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.person_outline),
                  labelText: _porCorresponsal
                      ? 'Nombre de quien consignó'
                      : 'Nombre del dueño de la cuenta',
                  hintText: 'Nombre y apellido',
                  helperText: _porCorresponsal
                      ? 'Como quedó registrado en el punto.'
                      : 'El titular de la cuenta de donde sale el dinero, '
                            'aunque no seas tú.',
                  helperMaxLines: 2,
                ),
              ),
              if (_porCorresponsal) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _corresponsal,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.storefront_outlined),
                    labelText: 'Punto donde consignaste',
                    hintText: 'Ej: Baloto de la esquina',
                    helperText: 'En el extracto aparece el punto, no tu nombre.',
                    helperMaxLines: 2,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              const _AvisoComprobante(),
              const SizedBox(height: AppSpacing.md),
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
                onPressed: _datosCompletos ? () => _pagar(vm) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rótulo de sección del formulario de pago.
class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: AppColors.inkMuted,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// Opción de origen del pago (cuenta propia vs. corresponsal).
class _OrigenChip extends StatelessWidget {
  const _OrigenChip({
    required this.icono,
    required this.titulo,
    required this.seleccionado,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        // Icono y texto en fila: la versión apilada gastaba el doble de alto
        // para decir lo mismo.
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: seleccionado ? AppColors.primary : AppColors.line,
            width: seleccionado ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icono,
              size: 18,
              color: seleccionado ? AppColors.primary : AppColors.inkMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                titulo,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: seleccionado ? AppColors.primary : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anticipa que después de registrar el pago se pide la foto del comprobante.
/// Decirlo antes evita que el conductor cierre la app pensando que terminó.
class _AvisoComprobante extends StatelessWidget {
  const _AvisoComprobante();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.accent),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Al terminar te pedimos la foto del comprobante: con ella '
              'confirmamos el mismo día.',
              style: TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
        ],
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
            child: Text(
              'Cuenta bloqueada por deuda',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
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
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                aFavor ? 'Saldo a favor' : 'Comisiones pendientes',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            Formato.moneda(
              aFavor ? billetera.saldoAFavor : billetera.deudaActual,
            ),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: billetera.bloqueado
                  ? AppColors.danger
                  : (aFavor ? AppColors.success : AppColors.ink),
            ),
          ),
          if (aFavor) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Pagaste de más, así que este dinero está a tu favor: tus próximas '
              'comisiones se descuentan de aquí antes de generar deuda.',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              billetera.deudaActual <= 0
                  ? 'No debes nada. De cada servicio entregado, la plataforma se '
                        'queda con el 15%: eso es lo que se acumula aquí.'
                  : 'Es lo que le debes a la plataforma por el 15% de los '
                        'servicios que ya entregaste. Al pasar el límite de '
                        '${Formato.moneda(billetera.limite)} dejas de recibir pedidos '
                        'hasta ponerte al día.',
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
            ),
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
                Text(
                  '${billetera.porcentajeUso}% del límite',
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Límite ${Formato.moneda(billetera.limite)}',
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
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
    final surface = bloqueado
        ? AppColors.dangerSurface
        : AppColors.successSurface;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Icon(
            bloqueado ? Icons.block : Icons.check_circle,
            color: color,
            size: 20,
          ),
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

  /// Pide la foto del comprobante y la adjunta al pago.
  Future<void> _adjuntar(BuildContext context, BilleteraViewModel vm) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comprobante de la transferencia',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'La captura de la app del banco o la foto del recibo del '
                    'corresponsal. Que se vean el monto y la fecha.',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null) return;
    final err = await vm.adjuntarComprobante(pago.id, source);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Comprobante enviado. Gracias.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BilleteraViewModel>();
    return MotoCard(
      color: AppColors.accentSurface,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pago de ${Formato.moneda(pago.valor)} por ${pago.medioPago.label} en revisión',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'Lo confirmamos al verificar la transferencia.',
                      style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              if (onVer != null)
                TextButton(onPressed: onVer, child: const Text('Ver')),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          // El comprobante es lo que decide si el pago se confirma hoy o en
          // tres días: por eso va aquí, y no escondido en el detalle.
          Row(
            children: [
              Icon(
                pago.tieneComprobante
                    ? Icons.check_circle_outline
                    : Icons.receipt_long_outlined,
                size: 18,
                color: pago.tieneComprobante
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  pago.tieneComprobante
                      ? 'Comprobante recibido'
                      : 'Falta el comprobante: adjúntalo para que lo validemos '
                            'más rápido.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: pago.tieneComprobante
                        ? AppColors.success
                        : AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (vm.subiendoComprobante)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: () => _adjuntar(context, vm),
                  child: Text(pago.tieneComprobante ? 'Cambiar' : 'Adjuntar'),
                ),
            ],
          ),
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
        child: Text(
          'Aún no has registrado pagos de comisión.',
          style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
      );
    }
    final ultimo = pagos.first;
    return MotoCard(
      onTap: onVer,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 20,
            color: AppColors.inkMuted,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis pagos',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Último: ${Formato.moneda(ultimo.valor)} · ${ultimo.estadoLabel.toLowerCase()}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkMuted,
                  ),
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
  const _HistorialSheet({required this.pagos, this.movimientos = const []});
  final List<PagoRealizado> pagos;

  /// Ajustes que registró el administrador. Van arriba y aparte: no los hizo el
  /// conductor, y verlos con su concepto es lo que evita que un abono parezca
  /// una deuda que bajó sola.
  final List<MovimientoSaldo> movimientos;

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
          const Text(
            'Mis movimientos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                if (movimientos.isNotEmpty) ...[
                  const _TituloSeccion('Ajustes del administrador'),
                  for (final m in movimientos) _FilaMovimiento(movimiento: m),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const _TituloSeccion('Mis pagos'),
                if (pagos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(
                      'Aún no has registrado pagos de comisión.',
                      style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                    ),
                  )
                else
                  for (final p in pagos) _FilaPago(pago: p),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.inkMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Un ajuste de saldo: signo, concepto, nota y fecha.
class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({required this.movimiento});
  final MovimientoSaldo movimiento;

  @override
  Widget build(BuildContext context) {
    final abono = movimiento.esAbono;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            abono ? Icons.add_circle_outline : Icons.remove_circle_outline,
            size: 20,
            color: abono ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movimiento.conceptoLegible,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (movimiento.nota.isNotEmpty)
                  Text(movimiento.nota,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.inkMuted)),
                if (movimiento.creadoEn != null)
                  Text(Formato.fechaHora(movimiento.creadoEn!),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkMuted)),
              ],
            ),
          ),
          Text(
            '${abono ? '+' : '−'}${Formato.moneda(movimiento.valor.abs())}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: abono ? AppColors.success : AppColors.warning,
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
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Formato.moneda(pago.valor),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${pago.medioPago.label} · ${Formato.fechaHora(pago.confirmadoEn ?? pago.creadoEn)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            pago.estadoLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
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
            child: Text(
              mensaje,
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: onCerrar,
            child: const Icon(
              Icons.close_rounded,
              color: AppColors.success,
              size: 18,
            ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Número copiado')));
  }

  @override
  Widget build(BuildContext context) {
    final esNequi = medio == MedioPago.nequi;
    final tiene = datos.tieneDatos(medio);
    final destino = esNequi ? datos.nequiNumero : datos.brebLlave;
    final titularRaw = esNequi ? datos.nequiTitular : datos.brebTitular;
    final titular = (titularRaw?.trim().isNotEmpty ?? false)
        ? titularRaw!.trim()
        : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.south_east_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: tiene
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transfiere a ${esNequi ? 'Nequi' : 'Bre-B'}:',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        destino!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      // El titular va con el mismo peso que el número: es lo
                      // que el conductor coteja en la app del banco antes de
                      // aceptar, y en letra chica se lo salta.
                      Text(
                        titular ?? 'Titular sin configurar',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
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
                            fontSize: 12,
                            color: AppColors.danger,
                          ),
                        ),
                      if (!esNequi &&
                          (datos.brebEntidad?.trim().isNotEmpty ?? false))
                        Text(
                          datos.brebEntidad!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkMuted,
                          ),
                        ),
                    ],
                  )
                : Text(
                    'Aún no hay una cuenta ${esNequi ? 'Nequi' : 'Bre-B'} configurada. Contacta al administrador.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.inkMuted,
                    ),
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
        Expanded(
          child: _MedioChip(vm: vm, medio: MedioPago.nequi),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MedioChip(vm: vm, medio: MedioPago.breB),
        ),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
              height: 30,
              child: Image.asset(_logoMedio(medio), fit: BoxFit.contain),
            ),
            const SizedBox(height: 4),
            // El check va en la misma línea que el nombre: como tercera fila se
            // llevaba 18dp por chip para repetir lo que ya dice el borde.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  medio.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: sel ? AppColors.primary : AppColors.ink,
                  ),
                ),
                if (sel) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ],
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
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  height: 36,
                  width: 36,
                  child: Image.asset(
                    _logoMedio(intencion.medioPago),
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Pago por ${intencion.medioPago.label}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _DatoFila(label: 'Monto', valor: Formato.moneda(intencion.monto)),
            _DatoFila(
              label: 'Transfiere a',
              valor: _destino ?? 'Sin configurar',
            ),
            _DatoFila(
              label: 'A nombre de',
              valor: _titular ?? 'Sin configurar (confírmalo antes de enviar)',
            ),
            _DatoFila(
              label: 'Estado',
              valor: intencion.pendiente
                  ? 'Pendiente de confirmación'
                  : intencion.estado,
            ),
            if (intencion.referenciaExterna != null)
              _DatoFila(
                label: 'Referencia',
                valor: intencion.referenciaExterna!,
              ),
            if (intencion.instrucciones != null &&
                intencion.instrucciones!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  intencion.instrucciones!,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
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
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/pedido_repository.dart';
import '../../../data/services/ofertas_service.dart';
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
  const PedidoEntranteScreen({super.key, required this.pedidoId, this.segundosIniciales});
  final int pedidoId;

  /// Ventana de respuesta del servidor (segundos restantes) para el countdown real.
  final int? segundosIniciales;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PedidoEntranteViewModel(
        locator<PedidoRepository>(),
        pedidoId,
        locator<OfertasService>(),
        segundosIniciales: segundosIniciales,
      )..cargar(),
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
            _CabeceraNuevo(
                segundos: vm.segundosRestantes,
                fraccion: vm.fraccionTiempo,
                expirado: expirado,
                avisoCierre: vm.avisoCierre),
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
                          referencia: pedido.referenciaRecogida,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Divider(height: 1),
                        ),
                        _PuntoRuta(
                          icon: Icons.location_on_outlined,
                          titulo: 'Entregar',
                          detalle: pedido.direccionDestino ?? '—',
                          referencia: pedido.referencia,
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

/// Encabezado con el tiempo restante como barra que se vacía y cambia de color.
/// La urgencia se ve de un vistazo: el conductor decide en la calle, muchas
/// veces con el casco puesto, y no está para leer y restar segundos.
class _CabeceraNuevo extends StatelessWidget {
  const _CabeceraNuevo({
    required this.segundos,
    required this.fraccion,
    required this.expirado,
    this.avisoCierre,
  });
  final int segundos;
  final double fraccion;
  final bool expirado;
  final String? avisoCierre;

  @override
  Widget build(BuildContext context) {
    final mm = (segundos ~/ 60).toString();
    final ss = (segundos % 60).toString().padLeft(2, '0');
    // Al cerrarse remotamente (tomado/cancelado) prima el aviso del backend.
    final textoTimer = expirado
        ? (avisoCierre ?? 'Oferta expirada')
        : 'Responde en $mm:$ss';
    final colorBarra = fraccion > 0.5
        ? AppColors.success
        : (fraccion > 0.25 ? AppColors.warning : AppColors.danger);
    return Container(
      width: double.infinity,
      color: AppColors.accent,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Text('¡Nuevo pedido!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(expirado ? Icons.timer_off_outlined : Icons.timer_outlined,
                  color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                textoTimer,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (!expirado) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraccion,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(colorBarra),
              ),
            ),
          ],
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
    this.referencia,
    this.color = AppColors.inkMuted,
  });
  final IconData icon;
  final String titulo;
  final String detalle;

  /// Referencia del punto (esquina, color de la fachada, piso…): en pueblo,
  /// suele valer más que la dirección para no dar vueltas.
  final String? referencia;
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
              if (referencia != null && referencia!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(referencia!.trim(),
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                color: AppColors.ink)),
                      ),
                    ],
                  ),
                ),
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

/// Cómo se arma el dinero del pedido: primero de dónde sale la tarifa sugerida
/// (recorrido + recargos), luego qué queda tras la comisión. Sin el desglose,
/// una sugerida "alta" por 20 minutos de cola parece un regalo y el conductor
/// la contraoferta a la baja sin saber qué está descontando.
class _Desglose extends StatelessWidget {
  const _Desglose({required this.vm});
  final PedidoEntranteViewModel vm;

  @override
  Widget build(BuildContext context) {
    final p = vm.pedido!;
    final hayRecargos = p.tieneRecargos;
    return MotoCard(
      color: AppColors.primarySurface,
      child: Column(
        children: [
          if (hayRecargos) ...[
            _Fila(
              label: 'Recorrido',
              valor: Formato.moneda(p.tarifaDistancia ?? 0),
              tenue: true,
            ),
            if ((p.recargoAdelanto ?? 0) > 0) ...[
              const SizedBox(height: 6),
              _Fila(
                label: 'Por adelantar la compra',
                valor: Formato.moneda(p.recargoAdelanto),
                tenue: true,
              ),
            ],
            if ((p.recargoEspera ?? 0) > 0) ...[
              const SizedBox(height: 6),
              _Fila(
                label: p.minutosEsperaEstimados != null
                    ? 'Por esperar (~${p.minutosEsperaEstimados} min)'
                    : 'Por esperar',
                valor: Formato.moneda(p.recargoEspera),
                tenue: true,
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
          ],
          _Fila(
            label: vm.esContraoferta ? 'Tu propuesta' : 'Tarifa sugerida',
            valor: Formato.moneda(vm.montoPropuesto),
          ),
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
          if (p.requiereCompra && (p.montoCompraEstimado ?? 0) > 0) ...[
            const SizedBox(height: 6),
            _Fila(
              label: 'Compra (te la reembolsa el cliente)',
              valor: Formato.moneda(p.montoCompraEstimado),
              tenue: true,
            ),
          ],
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
    this.tenue = false,
    this.valorColor,
  });
  final String label;
  final String valor;
  final bool bold;

  /// Fila de detalle (componente de la tarifa): más pequeña y apagada, para que
  /// el total y la ganancia sigan siendo lo primero que se lee.
  final bool tenue;
  final Color? valorColor;

  @override
  Widget build(BuildContext context) {
    final peso = bold ? FontWeight.w800 : FontWeight.w500;
    final tam = tenue ? 13.0 : 14.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontWeight: peso,
                  fontSize: tam,
                  color: tenue ? AppColors.inkMuted : AppColors.ink)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(valor,
            style: TextStyle(
                fontWeight: tenue ? FontWeight.w600 : FontWeight.w800,
                fontSize: bold ? 18 : tam,
                color: valorColor ?? (tenue ? AppColors.inkMuted : AppColors.ink))),
      ],
    );
  }
}

/// Ajuste de la contraoferta. La tarifa sugerida queda visible como ancla: sin
/// una referencia el conductor pide contra su imaginación y suele pasarse.
class _ProponerTarifa extends StatelessWidget {
  const _ProponerTarifa({required this.vm});
  final PedidoEntranteViewModel vm;

  @override
  Widget build(BuildContext context) {
    final diferencia = vm.montoPropuesto - vm.tarifaSugerida;
    return MotoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Proponer otra tarifa',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Sugerida ${Formato.moneda(vm.tarifaSugerida)}',
              style:
                  const TextStyle(color: AppColors.inkMuted, fontSize: 12.5)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _BotonAjuste(
                icon: Icons.remove_rounded,
                onTap: () => vm.ajustarMonto(-500),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(Formato.moneda(vm.montoPropuesto),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 22)),
                    if (diferencia != 0)
                      Text(
                        diferencia > 0
                            ? '+${Formato.moneda(diferencia)} sobre la sugerida'
                            : '${Formato.moneda(diferencia)} bajo la sugerida',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: diferencia > 0
                              ? AppColors.warning
                              : AppColors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
              _BotonAjuste(
                icon: Icons.add_rounded,
                onTap: () => vm.ajustarMonto(500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botón circular de ±$500 con área táctil holgada (se usa con guantes y en
/// movimiento; un icono de 24dp se falla demasiado).
class _BotonAjuste extends StatelessWidget {
  const _BotonAjuste({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySurface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSpacing.minTouchTarget,
          height: AppSpacing.minTouchTarget,
          child: Icon(icon, color: AppColors.primary, size: 26),
        ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // La cifra que realmente decide es la ganancia neta, no la tarifa
          // bruta: va pegada al botón y se actualiza con la contraoferta.
          Row(
            children: [
              const Icon(Icons.savings_outlined,
                  size: 18, color: AppColors.success),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Ganas por este pedido',
                    style: TextStyle(fontSize: 13, color: AppColors.inkMuted)),
              ),
              Text(Formato.moneda(vm.gananciaNeta),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (vm.enviando || vm.rechazando)
                      ? null
                      : () => onRechazar(context, vm),
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
                  onPressed: () =>
                      onEnviar(context, vm, aceptarSugerida: !contra),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

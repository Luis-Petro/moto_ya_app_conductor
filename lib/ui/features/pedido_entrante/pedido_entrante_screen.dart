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
import '../../core/widgets/mascota_animada.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../router.dart';
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
    if (vm.estado == EstadoEntrante.noDisponible) {
      return _OfertaCerrada(motivo: vm.motivoNoDisponible);
    }
    if (vm.estado == EstadoEntrante.error) {
      return Scaffold(
        body: SafeArea(
          child: ErrorRetry(
            message: vm.error ?? 'No pudimos cargar el pedido',
            onRetry: vm.cargar,
            esRed: vm.errorEsRed,
          ),
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
            // Todo lo que decide la oferta cabe sin desplazar: el conductor
            // tiene un minuto y suele mirar la pantalla con el casco puesto.
            // Lo que se puede desplegar (desglose, mandado largo) va plegado.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
                    AppSpacing.lg, AppSpacing.md),
                children: [
                  _TarjetaRuta(pedido: pedido),
                  const SizedBox(height: AppSpacing.sm),
                  _TarjetaDinero(vm: vm),
                  const SizedBox(height: AppSpacing.sm),
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

/// La oferta ya no está: el pedido lo tomó otro o el cliente lo canceló.
///
/// Es un final, no un fallo. Antes caía en la misma pantalla que un error de
/// red —nube tachada y "Reintentar"—, y ese botón no podía funcionar: el 403 iba
/// a ser 403 todas las veces. Aquí hay una salida sola, y lleva al Inicio, que
/// es donde están sus pedidos y sus ofertas vivas.
class _OfertaCerrada extends StatelessWidget {
  const _OfertaCerrada({required this.motivo});

  final String motivo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MascotaAnimada(pose: PoseMascota.triste, alto: 150),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Esta oferta ya no está disponible',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  motivo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: 240,
                  child: PrimaryButton(
                    label: 'Volver al inicio',
                    icon: Icons.home_rounded,
                    // `go` y no `pop`: abierta desde una notificación con la app
                    // cerrada no hay nada debajo a lo que volver.
                    onPressed: () => context.go(Rutas.inicio),
                  ),
                ),
              ],
            ),
          ),
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
    // Título y reloj comparten línea: cada píxel del encabezado es un píxel que
    // le quita a la ruta y al dinero, que es lo que decide la oferta.
    return Container(
      width: double.infinity,
      color: AppColors.accent,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('¡Nuevo pedido!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ),
              Icon(expirado ? Icons.timer_off_outlined : Icons.timer_outlined,
                  color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                textoTimer,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
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

/// Cuánto tiempo se le va en el pedido, en grande y separado de la distancia.
///
/// Es el dato con el que el conductor decide si contraofertar: dos pedidos de
/// la misma tarifa no valen lo mismo si uno son 8 minutos y el otro 25 más una
/// cola de 15. Antes iba como un icono de 15dp al lado de los kilómetros, que
/// es donde va lo que no se lee.
class _TiempoEstimado extends StatelessWidget {
  const _TiempoEstimado({required this.pedido});
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final espera =
        pedido.requiereEspera ? (pedido.minutosEsperaEstimados ?? 0) : 0;
    final viajeMin = pedido.duracionEstimadaSegundos == null
        ? null
        : (pedido.duracionEstimadaSegundos! / 60).round();
    // Total = recorrido + cola declarada: el tiempo real que le cuesta el
    // pedido, que es contra lo que compara la tarifa.
    final total = viajeMin == null ? null : viajeMin + espera;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 20, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == null
                      ? 'Tiempo estimado no disponible'
                      : '~$total min en total',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent),
                ),
                Text(
                  espera > 0 && viajeMin != null
                      ? 'Recorrido ~$viajeMin min + espera ~$espera min'
                      : 'Recorrido recogida → entrega',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          if (espera > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: const Text('Hay cola',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.warning)),
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

/// Tarjeta única de "qué hay que hacer": categoría, distancia/tiempo, los dos
/// puntos con su referencia, el mandado y el adelanto de la compra.
///
/// Antes eran dos tarjetas; juntarlas ahorra un salto de lectura y el alto que
/// hacía falta para que el dinero cupiera en la misma pantalla. El texto del
/// mandado va a dos líneas y se despliega al tocarlo: los largos son la
/// excepción y no pueden empujar la ganancia fuera de vista.
class _TarjetaRuta extends StatefulWidget {
  const _TarjetaRuta({required this.pedido});
  final Pedido pedido;

  @override
  State<_TarjetaRuta> createState() => _TarjetaRutaState();
}

class _TarjetaRutaState extends State<_TarjetaRuta> {
  bool _mandadoCompleto = false;

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    final descripcion = pedido.descripcion.trim();
    return MotoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(pedido.categoria.icon, size: 17, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(pedido.categoria.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5)),
              const Spacer(),
              const Icon(Icons.straighten_rounded,
                  size: 15, color: AppColors.inkMuted),
              const SizedBox(width: 3),
              Text(Formato.distancia(pedido.distanciaEstimadaMetros),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _TiempoEstimado(pedido: pedido),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1),
          ),
          _PuntoRuta(
            icon: Icons.circle_outlined,
            titulo: 'Recoger',
            detalle: pedido.direccionRecogida ?? descripcion,
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
          if (descripcion.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1),
            ),
            InkWell(
              onTap: () =>
                  setState(() => _mandadoCompleto = !_mandadoCompleto),
              child: Text(
                descripcion,
                maxLines: _mandadoCompleto ? null : 2,
                overflow: _mandadoCompleto ? null : TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
          ],
          if (pedido.requiereCompra) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      pedido.montoCompraEstimado != null
                          ? 'Adelantas ${Formato.moneda(pedido.montoCompraEstimado)} · te los reembolsa el cliente'
                          : 'Adelantas la compra · te la reembolsa el cliente',
                      style:
                          const TextStyle(fontSize: 12.5, color: AppColors.ink),
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

/// El dinero del pedido. Arriba, en grande, lo único que decide: lo que le
/// queda al conductor. Debajo, en una línea, tarifa y comisión.
///
/// El desglose de la tarifa (recorrido + adelanto + espera) va plegado: importa
/// cuando la sugerida sorprende — una "alta" por 20 minutos de cola parece un
/// regalo si no se ve de dónde sale — pero no en cada oferta, y desplegado
/// empujaba la ganancia fuera de la pantalla.
class _TarjetaDinero extends StatefulWidget {
  const _TarjetaDinero({required this.vm});
  final PedidoEntranteViewModel vm;

  @override
  State<_TarjetaDinero> createState() => _TarjetaDineroState();
}

class _TarjetaDineroState extends State<_TarjetaDinero> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final p = vm.pedido!;
    final hayRecargos = p.tieneRecargos;
    return MotoCard(
      color: AppColors.primarySurface,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text('Ganas por este pedido',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted)),
              ),
              Text(Formato.moneda(vm.gananciaNeta),
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${vm.esContraoferta ? 'Tu propuesta' : 'Tarifa'} '
                  '${Formato.moneda(vm.montoPropuesto)} · comisión '
                  '${Formato.moneda(vm.comision)}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.inkMuted),
                ),
              ),
              if (hayRecargos)
                InkWell(
                  onTap: () => setState(() => _abierto = !_abierto),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        Text(_abierto ? 'Ocultar' : 'Ver desglose',
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                        Icon(
                            _abierto
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 18,
                            color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (hayRecargos && _abierto) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1),
            ),
            _Fila(
              label: 'Recorrido',
              valor: Formato.moneda(p.tarifaDistancia ?? 0),
              tenue: true,
            ),
            if ((p.recargoAdelanto ?? 0) > 0) ...[
              const SizedBox(height: 4),
              _Fila(
                label: 'Por adelantar la compra',
                valor: Formato.moneda(p.recargoAdelanto),
                tenue: true,
              ),
            ],
            if ((p.recargoEspera ?? 0) > 0) ...[
              const SizedBox(height: 4),
              _Fila(
                label: p.minutosEsperaEstimados != null
                    ? 'Por esperar (~${p.minutosEsperaEstimados} min)'
                    : 'Por esperar',
                valor: Formato.moneda(p.recargoEspera),
                tenue: true,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Componente del desglose de la tarifa: pequeña y apagada, para que la
/// ganancia siga siendo lo primero que se lee.
class _Fila extends StatelessWidget {
  const _Fila({
    required this.label,
    required this.valor,
    this.tenue = false,
  });
  final String label;
  final String valor;
  final bool tenue;

  @override
  Widget build(BuildContext context) {
    final tam = tenue ? 13.0 : 14.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: tam,
                  color: tenue ? AppColors.inkMuted : AppColors.ink)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(valor,
            style: TextStyle(
                fontWeight: tenue ? FontWeight.w600 : FontWeight.w800,
                fontSize: tam,
                color: tenue ? AppColors.inkMuted : AppColors.ink)),
      ],
    );
  }
}

/// Ajuste de la contraoferta en una sola fila. La sugerida queda como ancla:
/// sin una referencia el conductor pide contra su imaginación y suele pasarse.
class _ProponerTarifa extends StatelessWidget {
  const _ProponerTarifa({required this.vm});
  final PedidoEntranteViewModel vm;

  @override
  Widget build(BuildContext context) {
    final diferencia = vm.montoPropuesto - vm.tarifaSugerida;
    return MotoCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Proponer otra tarifa',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(
                  diferencia == 0
                      ? 'Sugerida ${Formato.moneda(vm.tarifaSugerida)}'
                      : (diferencia > 0
                          ? '+${Formato.moneda(diferencia)} sobre la sugerida'
                          : '${Formato.moneda(diferencia)} bajo la sugerida'),
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
            icon: Icons.remove_rounded,
            onTap: () => vm.ajustarMonto(-500),
          ),
          SizedBox(
            width: 96,
            child: Text(Formato.moneda(vm.montoPropuesto),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 19)),
          ),
          _BotonAjuste(
            icon: Icons.add_rounded,
            onTap: () => vm.ajustarMonto(500),
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
      // La ganancia ya va en grande arriba: repetirla aquí solo costaba alto.
      child: Row(
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
              onPressed: () => onEnviar(context, vm, aceptarSugerida: !contra),
            ),
          ),
        ],
      ),
    );
  }
}

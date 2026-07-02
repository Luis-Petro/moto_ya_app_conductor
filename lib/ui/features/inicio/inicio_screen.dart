import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../router.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/ofertas_service.dart';
import '../../../di/locator.dart';
import '../../core/format/formato.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/moto_card.dart';
import 'inicio_view_model.dart';

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InicioViewModel(
        locator<ConductorRepository>(),
        locator<PedidoRepository>(),
        locator<LocationService>(),
        locator<UsuarioRepository>(),
        locator<OfertasService>(),
      )..cargar(),
      child: const _InicioView(),
    );
  }
}

class _InicioView extends StatelessWidget {
  const _InicioView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InicioViewModel>();
    return Scaffold(
      body: SafeArea(
        child: vm.cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _Header(vm: vm),
                  const SizedBox(height: AppSpacing.lg),
                  if (vm.enRevision || vm.rechazado) ...[
                    _RevisionBanner(vm: vm),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (vm.pedidoActivo != null) ...[
                    _ActivoBanner(vm: vm),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (vm.ofertaActual != null && vm.pedidoActivo == null) ...[
                    _OfertaBanner(vm: vm),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _ToggleEnLinea(vm: vm),
                  const SizedBox(height: AppSpacing.lg),
                  _Ganancias(vm: vm),
                  const SizedBox(height: AppSpacing.lg),
                  _Heatmap(vm: vm),
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.vm});
  final InicioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final rating = vm.calificacion;
    return Row(
      children: [
        InitialsAvatar(initials: vm.iniciales, imageUrl: vm.fotoUrl, radius: 22),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vm.nombre ?? 'Conductor',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 15, color: AppColors.star),
                  const SizedBox(width: 2),
                  Text(rating != null ? rating.toStringAsFixed(1) : '—',
                      style: const TextStyle(
                          color: AppColors.inkMuted, fontSize: 13)),
                  const Text(' · La Ceja',
                      style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        const Icon(Icons.notifications_none_rounded, color: AppColors.inkMuted),
      ],
    );
  }
}

class _ActivoBanner extends StatelessWidget {
  const _ActivoBanner({required this.vm});
  final InicioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final p = vm.pedidoActivo!;
    return MotoCard(
      color: AppColors.accent,
      onTap: () async {
        await context.push(Rutas.pedidoActivo(p.id));
        await vm.refrescar();
      },
      child: Row(
        children: [
          const Icon(Icons.navigation_rounded, color: Colors.white),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pedido en curso',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                Text(
                  '${p.categoria.label} · ${p.estado.label}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const Text('Continuar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _OfertaBanner extends StatelessWidget {
  const _OfertaBanner({required this.vm});
  final InicioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final oferta = vm.ofertaActual!;
    return MotoCard(
      color: AppColors.primarySurface,
      borderColor: AppColors.primary,
      onTap: () {
        context.push(Rutas.pedidoEntrante(oferta.id));
        vm.descartarOferta();
      },
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¡Nuevo pedido cerca!',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  '${oferta.categoria.label} · sugerido ${Formato.moneda(oferta.tarifaSugerida)}',
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _ToggleEnLinea extends StatelessWidget {
  const _ToggleEnLinea({required this.vm});
  final InicioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final bloqueado = vm.bloqueadoPorDeuda;
    final noHabilitado = !vm.habilitado && !bloqueado; // en revisión / rechazado
    final deshabilitado = bloqueado || noHabilitado;
    final enLinea = vm.enLinea;
    final color = deshabilitado
        ? AppColors.danger
        : (enLinea ? AppColors.accent : AppColors.inkMuted);
    return MotoCard(
      color: enLinea && !deshabilitado ? AppColors.accent : AppColors.surface,
      child: Row(
        children: [
          Icon(deshabilitado ? Icons.lock_outline : Icons.bolt_rounded,
              color: enLinea && !deshabilitado ? Colors.white : color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bloqueado
                      ? 'Bloqueado por deuda'
                      : noHabilitado
                          ? 'Cuenta no habilitada'
                          : (enLinea ? 'En línea' : 'Fuera de línea'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: enLinea && !deshabilitado ? Colors.white : AppColors.ink,
                  ),
                ),
                Text(
                  bloqueado
                      ? 'Paga tu deuda para recibir pedidos'
                      : noHabilitado
                          ? 'En revisión: aún no puedes recibir pedidos'
                          : (enLinea ? 'Recibiendo pedidos' : 'No recibes pedidos'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: enLinea && !deshabilitado
                        ? Colors.white70
                        : AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (vm.cambiandoEstado)
            const SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Switch(
              value: enLinea,
              activeColor: Colors.white,
              activeTrackColor: AppColors.success,
              onChanged: deshabilitado
                  ? null
                  : (v) async {
                      final ok = await vm.alternarEnLinea(v);
                      if (!ok && context.mounted && vm.bloqueadoPorDeuda) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Cuenta bloqueada por deuda. Ve a Billetera.')),
                        );
                      }
                    },
            ),
        ],
      ),
    );
  }
}

/// Aviso en Inicio cuando la cuenta está en revisión o fue rechazada.
class _RevisionBanner extends StatelessWidget {
  const _RevisionBanner({required this.vm});
  final InicioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final rechazado = vm.rechazado;
    return MotoCard(
      color: rechazado ? AppColors.dangerSurface : AppColors.primarySurface,
      borderColor: rechazado ? AppColors.danger : AppColors.primary,
      child: Row(
        children: [
          Icon(rechazado ? Icons.error_outline : Icons.hourglass_top_rounded,
              color: rechazado ? AppColors.danger : AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rechazado ? 'Cuenta rechazada' : 'Cuenta en revisión',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  rechazado
                      ? (vm.motivoRechazo?.trim().isNotEmpty ?? false
                          ? vm.motivoRechazo!
                          : 'Tus documentos fueron rechazados. Contáctanos para corregirlos.')
                      : 'Estamos revisando tus documentos. Te habilitaremos para recibir pedidos muy pronto.',
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ganancias extends StatelessWidget {
  const _Ganancias({required this.vm});
  final InicioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final h = vm.minutosEnLinea ~/ 60;
    final m = vm.minutosEnLinea % 60;
    final tiempo = h > 0 ? '${h}h ${m}m' : '${m}m';
    final acept = vm.tasaAceptacion;
    return MotoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ganancias de hoy',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
          const SizedBox(height: 2),
          Text(Formato.moneda(vm.gananciasHoy),
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Metrica(valor: '${vm.pedidosHoy}', etiqueta: 'pedidos'),
              _Metrica(valor: tiempo, etiqueta: 'en línea'),
              _Metrica(
                  valor: acept != null ? '${acept.round()}%' : '—',
                  etiqueta: 'aceptación'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({required this.valor, required this.etiqueta});
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(valor,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        Text(etiqueta,
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
      ],
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.vm});
  final InicioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final centro = vm.ubicacion ?? LocationService.fallbackCenter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Zonas con más demanda',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: centro,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
              ),
              children: [
                osmTileLayer(),
                // Aproximación de demanda alrededor del conductor (design Q5:
                // sin endpoint de demanda, se muestra una referencia visual).
                CircleLayer(
                  circles: [
                    _zona(centro.latitude + 0.004, centro.longitude + 0.003,
                        AppColors.danger, 320),
                    _zona(centro.latitude - 0.003, centro.longitude - 0.004,
                        AppColors.warning, 260),
                    _zona(centro.latitude + 0.001, centro.longitude - 0.006,
                        AppColors.success, 220),
                  ],
                ),
                MarkerLayer(markers: [usuarioMarker(centro)]),
                osmAttribution(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  CircleMarker _zona(double lat, double lng, Color color, double radio) {
    return CircleMarker(
      point: LatLng(lat, lng),
      radius: radio,
      useRadiusInMeter: true,
      color: color.withValues(alpha: 0.18),
      borderColor: color.withValues(alpha: 0.35),
      borderStrokeWidth: 1,
    );
  }
}

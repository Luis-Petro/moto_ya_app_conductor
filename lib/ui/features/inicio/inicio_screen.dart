import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../router.dart';

import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/municipio_repository.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/ofertas_service.dart';
import '../../../data/services/permisos_service.dart';
import '../../../di/locator.dart';
import '../../../domain/models/demanda_zonas.dart';
import '../../core/format/formato.dart';
import '../../core/tab_activa.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/banner_version.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/skeleton.dart';
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
        locator<MunicipioRepository>(),
        locator<PermisosService>(),
        locator<TabActiva>(),
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
            ? const SkeletonInicio()
            // El mapa de zonas se dimensiona contra el alto real disponible (no
            // un valor fijo): es la pantalla donde el conductor decide dónde
            // pararse. Sigue dentro del ListView para no perder el gesto de
            // refrescar ni desbordar cuando hay banners de revisión/oferta.
            : LayoutBuilder(
                builder: (context, constraints) => RefreshIndicator(
                  onRefresh: vm.refrescar,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _Header(vm: vm),
                      const SizedBox(height: AppSpacing.md),
                      // Aviso de versión nueva (descartable, nunca bloquea).
                      const BannerVersion(),
                      if (vm.enRevision || vm.rechazado) ...[
                        _RevisionBanner(vm: vm),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (vm.pedidoActivo != null) ...[
                        _ActivoBanner(vm: vm),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (vm.ofertaActual != null &&
                          vm.pedidoActivo == null) ...[
                        _OfertaBanner(vm: vm),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _ToggleEnLinea(vm: vm),
                      const SizedBox(height: AppSpacing.lg),
                      _Ganancias(vm: vm),
                      const SizedBox(height: AppSpacing.lg),
                      _ZonasDemanda(
                        vm: vm,
                        alturaMapa: (constraints.maxHeight * 0.55).clamp(
                          220,
                          520,
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

class _Header extends StatelessWidget {
  const _Header({required this.vm});
  final InicioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final rating = vm.calificacion;
    return Row(
      children: [
        InitialsAvatar(
          initials: vm.iniciales,
          imageUrl: vm.fotoUrl,
          radius: 22,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vm.nombre ?? 'Conductor',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 15,
                    color: AppColors.star,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    rating != null ? rating.toStringAsFixed(1) : '—',
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                  if (vm.municipioNombre != null)
                    Flexible(
                      child: Text(
                        ' · ${vm.municipioNombre}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        // Refresco manual (además del gesto de arrastrar hacia abajo).
        IconButton(
          onPressed: vm.refrescar,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh_rounded, color: AppColors.inkMuted),
        ),
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
                const Text(
                  'Pedido en curso',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${p.categoria.label} · ${p.estado.label}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const Text(
            'Continuar',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
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
    final pedido = oferta.pedido;
    return MotoCard(
      color: AppColors.primarySurface,
      borderColor: AppColors.primary,
      onTap: () async {
        // Pasa la ventana del servidor para el countdown real de la tarjeta.
        await context.push(
          Rutas.pedidoEntrante(pedido.id, segundos: oferta.segundosRestantes),
        );
        vm.descartarOferta();
        // Responder (o rechazar) mueve la tasa de aceptación en el backend: sin
        // este refresco el Inicio seguiría mostrando el valor cacheado.
        await vm.refrescar();
      },
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Nuevo pedido cerca!',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${pedido.categoria.label} · sugerido ${Formato.moneda(pedido.tarifaSugerida)}',
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 13,
                  ),
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

/// Interruptor de disponibilidad: la acción más importante de la app del
/// conductor. Toda la tarjeta es el área táctil (no solo el switch de 40dp), y
/// fuera de línea el texto nombra la consecuencia real —los pedidos se ofrecen
/// a otros— en vez de un neutro "no recibes pedidos".
class _ToggleEnLinea extends StatelessWidget {
  const _ToggleEnLinea({required this.vm});
  final InicioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final bloqueado = vm.bloqueadoPorDeuda;
    final noHabilitado =
        !vm.habilitado && !bloqueado; // en revisión / rechazado
    final deshabilitado = bloqueado || noHabilitado;
    final enLinea = vm.enLinea;
    final activo = enLinea && !deshabilitado;
    final color = deshabilitado
        ? AppColors.danger
        : (enLinea ? AppColors.accent : AppColors.inkMuted);
    return MotoCard(
      color: activo ? AppColors.accent : AppColors.surface,
      borderColor: activo
          ? AppColors.accent
          : (deshabilitado ? AppColors.danger : AppColors.line),
      onTap: (deshabilitado || vm.cambiandoEstado)
          ? null
          : () => _alternar(context, vm, !enLinea),
      child: Row(
        children: [
          Icon(
            deshabilitado ? Icons.lock_outline : Icons.bolt_rounded,
            color: activo ? Colors.white : color,
          ),
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
                    color: activo ? Colors.white : AppColors.ink,
                  ),
                ),
                Text(
                  bloqueado
                      ? 'Paga tu deuda para recibir pedidos'
                      : noHabilitado
                      ? 'En revisión: aún no puedes recibir pedidos'
                      : (enLinea
                            ? 'Recibiendo pedidos de tu zona'
                            : 'Los pedidos de tu zona se le ofrecen a otros conductores'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: activo ? Colors.white70 : AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (vm.cambiandoEstado)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            // Se mantiene por legibilidad del estado; el toque real lo captura
            // la tarjeta entera.
            IgnorePointer(
              child: Switch(
                value: enLinea,
                activeColor: Colors.white,
                activeTrackColor: AppColors.success,
                onChanged: deshabilitado ? null : (_) {},
              ),
            ),
        ],
      ),
    );
  }

  /// Aplica el cambio de estado y traduce el desenlace a un aviso. Ponerse en
  /// línea exige ubicación y notificaciones: si faltan, ofrece abrir Ajustes.
  Future<void> _alternar(
    BuildContext context,
    InicioViewModel vm,
    bool valor,
  ) async {
    final r = await vm.alternarEnLinea(valor);
    if (!context.mounted) return;
    switch (r) {
      case ResultadoEnLinea.ok:
      case ResultadoEnLinea.noHabilitado:
        break;
      case ResultadoEnLinea.bloqueadoDeuda:
        _snack(context, 'Cuenta bloqueada por deuda. Ve a Billetera.');
        break;
      case ResultadoEnLinea.faltaUbicacionServicio:
        _dialogoPermiso(
          context,
          titulo: 'Activa la ubicación',
          mensaje:
              'Para recibir pedidos necesitas el GPS encendido: te asignamos '
              'los pedidos más cercanos a ti.',
          onAjustes: vm.abrirConfiguracionUbicacion,
        );
        break;
      case ResultadoEnLinea.faltaUbicacionPermiso:
        _dialogoPermiso(
          context,
          titulo: 'Permite la ubicación',
          mensaje:
              'motoYa necesita tu ubicación para asignarte pedidos cercanos. '
              'Actívala en Ajustes para ponerte en línea.',
          onAjustes: vm.abrirConfiguracionApp,
        );
        break;
      case ResultadoEnLinea.faltaNotificaciones:
        _dialogoPermiso(
          context,
          titulo: 'Activa las notificaciones',
          mensaje:
              'Sin notificaciones no podemos avisarte de nuevos pedidos. '
              'Actívalas en Ajustes para ponerte en línea.',
          onAjustes: vm.abrirConfiguracionApp,
        );
        break;
      case ResultadoEnLinea.error:
        _snack(context, vm.error ?? 'No pudimos cambiar tu estado');
        break;
    }
  }

  void _snack(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _dialogoPermiso(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    required Future<void> Function() onAjustes,
  }) {
    showDialog<void>(
      context: context,
      // Dentro de tabs (StatefulShellRoute): con el navigator raíz el diálogo
      // pinta un velo negro sobre el shell.
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onAjustes();
            },
            child: const Text('Abrir ajustes'),
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
          Icon(
            rechazado ? Icons.error_outline : Icons.hourglass_top_rounded,
            color: rechazado ? AppColors.danger : AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rechazado ? 'Cuenta rechazada' : 'Cuenta en revisión',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  rechazado
                      ? (vm.motivoRechazo?.trim().isNotEmpty ?? false
                            ? vm.motivoRechazo!
                            : 'Tus documentos fueron rechazados. Contáctanos para corregirlos.')
                      : 'Estamos revisando tus documentos. Te habilitaremos para recibir pedidos muy pronto.',
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 13,
                  ),
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
          const Text(
            'Ganancias de hoy',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            Formato.moneda(vm.gananciasHoy),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
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
                etiqueta: 'aceptación',
              ),
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
        Text(
          valor,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        Text(
          etiqueta,
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
        ),
      ],
    );
  }
}

/// Dónde han salido pedidos en las últimas horas, con datos del backend.
///
/// Antes esto dibujaba tres círculos alrededor del conductor con offsets fijos:
/// parecía información y no lo era. Si el servidor no tiene datos suficientes,
/// ahora se dice; no se pinta un mapa inventado sobre el que alguien podría
/// decidir dónde pararse a esperar.
class _ZonasDemanda extends StatelessWidget {
  const _ZonasDemanda({required this.vm, required this.alturaMapa});
  final InicioViewModel vm;

  /// Alto del mapa, calculado por la pantalla contra el espacio disponible.
  final double alturaMapa;

  @override
  Widget build(BuildContext context) {
    final d = vm.demanda;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Dónde están pidiendo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            if (vm.cargandoDemanda)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          d != null && d.tieneDatos
              ? '${d.totalPedidos} pedidos en las últimas ${d.periodoHoras} h · '
                    'actualizado ${Formato.hora(d.actualizadoEn)}'
              : 'Zonas de recogida de los pedidos recientes de tu municipio.',
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (d == null && !vm.cargandoDemanda)
          _AvisoDemanda(
            icono: Icons.cloud_off_outlined,
            texto: 'No pudimos cargar las zonas de demanda.',
            accion: vm.cargarDemanda,
          )
        else if (d != null && !d.tieneDatos)
          const _AvisoDemanda(
            icono: Icons.query_stats_outlined,
            texto:
                'Aún no hay suficientes pedidos recientes por aquí para '
                'señalar zonas. Cuando los haya, aparecen en el mapa.',
          )
        else if (d != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: SizedBox(
              height: alturaMapa,
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints([
                      for (final c in d.celdas) c.centro,
                      if (vm.ubicacion != null) vm.ubicacion!,
                    ]),
                    padding: const EdgeInsets.all(28),
                  ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  osmTileLayer(),
                  CircleLayer(
                    circles: [
                      for (final c in d.celdas)
                        CircleMarker(
                          point: c.centro,
                          // ~media celda de la rejilla del backend (0.005°).
                          radius: 280,
                          useRadiusInMeter: true,
                          color: _color(c.nivel).withValues(alpha: 0.18),
                          borderColor: _color(c.nivel).withValues(alpha: 0.35),
                          borderStrokeWidth: 1,
                        ),
                    ],
                  ),
                  if (vm.ubicacion != null)
                    MarkerLayer(markers: [usuarioMarker(vm.ubicacion!)]),
                  osmAttribution(),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final n in NivelDemanda.values) ...[
                _PuntoLeyenda(color: _color(n), label: n.label),
                const SizedBox(width: AppSpacing.md),
              ],
            ],
          ),
        ],
      ],
    );
  }

  static Color _color(NivelDemanda n) => switch (n) {
    NivelDemanda.alta => AppColors.danger,
    NivelDemanda.media => AppColors.warning,
    NivelDemanda.baja => AppColors.success,
  };
}

class _PuntoLeyenda extends StatelessWidget {
  const _PuntoLeyenda({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.35),
            border: Border.all(color: color),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

class _AvisoDemanda extends StatelessWidget {
  const _AvisoDemanda({required this.icono, required this.texto, this.accion});
  final IconData icono;
  final String texto;
  final VoidCallback? accion;

  @override
  Widget build(BuildContext context) {
    return MotoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
          if (accion != null)
            TextButton(onPressed: accion, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../core/widgets/beta_chip.dart';
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
    // Los avisos (revisión, foto, pedido activo, oferta) son transitorios pero
    // empujan: con alguno en pantalla el mapa ya no puede quedarse con "lo que
    // sobre" —sobraría casi nada— y pasa a un alto fijo con scroll.
    final hayAvisos =
        vm.enRevision ||
        vm.rechazado ||
        !vm.tieneFotoPerfil ||
        vm.pedidoActivo != null ||
        vm.ofertaActual != null;
    return Scaffold(
      body: SafeArea(
        child: vm.cargando
            ? const SkeletonInicio()
            : RefreshIndicator(
                onRefresh: vm.refrescar,
                child: CustomScrollView(
                  // Con el contenido justo la lista no scrollea sola; esto
                  // conserva el gesto de arrastrar para refrescar.
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        0,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _Header(vm: vm),
                          const SizedBox(height: AppSpacing.md),
                          // Aviso de versión nueva (descartable, nunca bloquea).
                          const BannerVersion(),
                          if (vm.enRevision || vm.rechazado) ...[
                            _RevisionBanner(vm: vm),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (!vm.tieneFotoPerfil) ...[
                            const _FotoPerfilBanner(),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (vm.pedidoActivo != null) ...[
                            _ActivoBanner(vm: vm),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (vm.ofertaActual != null &&
                              vm.pedidoActivo == null) ...[
                            _OfertaBanner(vm: vm),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          _ToggleEnLinea(vm: vm),
                          const SizedBox(height: AppSpacing.md),
                          _Ganancias(vm: vm),
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      // Sin avisos el mapa ocupa exactamente el alto que queda:
                      // se ve entero, con su leyenda, sin hacer scroll. Es la
                      // pantalla donde el conductor decide dónde pararse.
                      sliver: hayAvisos
                          ? SliverToBoxAdapter(
                              child: _ZonasDemanda(vm: vm, alturaMapa: 260),
                            )
                          : SliverFillRemaining(
                              hasScrollBody: true,
                              child: _ZonasDemanda(vm: vm),
                            ),
                    ),
                  ],
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
        // La app está en pruebas y se dice donde se ve siempre, no escondido en
        // un "acerca de".
        const BetaChip(),
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
  /// Divulgación destacada del uso de la ubicación, **antes** del diálogo del
  /// sistema. Es requisito de las tiendas y tiene que decir las tres cosas:
  /// qué se comparte, cuándo, y que sigue con la app cerrada. Devuelve `true` si
  /// el conductor quiere continuar.
  Future<bool> _explicarUbicacion(BuildContext context) async {
    final continuar = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => AlertDialog(
        title: const Text('Vamos a usar tu ubicación'),
        content: const Text(
          'Mientras estés EN LÍNEA, motoYa comparte tu ubicación con la plataforma '
          'para asignarte los pedidos que tengas cerca y para que el cliente pueda '
          'seguir su domicilio.\n\n'
          'Esto sigue funcionando con la app minimizada o la pantalla apagada, y en '
          'ese caso verás una notificación permanente que te lo recuerda.\n\n'
          'Al ponerte fuera de línea deja de compartirse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    return continuar == true;
  }

  Future<void> _alternar(
    BuildContext context,
    InicioViewModel vm,
    bool valor,
  ) async {
    // Ponerse en línea es lo que dispara la petición de ubicación: si aún no está
    // concedida, primero se explica para qué.
    if (valor && await vm.necesitaExplicarUbicacion()) {
      if (!context.mounted) return;
      if (!await _explicarUbicacion(context)) return;
      if (!context.mounted) return;
    }
    final r = await vm.alternarEnLinea(valor);
    if (!context.mounted) return;
    switch (r) {
      case ResultadoEnLinea.ok:
      case ResultadoEnLinea.noHabilitado:
        break;
      case ResultadoEnLinea.bloqueadoDeuda:
        _snack(context, 'Cuenta bloqueada por deuda. Ve a Billetera.');
        break;
      case ResultadoEnLinea.faltaFotoPerfil:
        _snack(
          context,
          'Ponte una foto de perfil para recibir pedidos: toca el aviso de '
          'arriba.',
        );
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

/// Aviso en Inicio mientras el conductor no tenga foto de perfil.
///
/// Es requisito para ponerse en línea: el cliente decide a quién le acepta la
/// propuesta viendo quién es, y una silueta gris al lado de una cara real
/// pierde siempre. Va aquí, con la cámara a un toque, porque el Perfil es una
/// pestaña a la que nadie entra si nada le obliga.
class _FotoPerfilBanner extends StatelessWidget {
  const _FotoPerfilBanner();

  Future<void> _elegir(BuildContext context, InicioViewModel vm) async {
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
                    'Tu foto de perfil',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Que se te vea la cara, de frente y con buena luz. Es la '
                    'que ve el cliente al elegir conductor.',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null) return;
    final err = await vm.subirFotoPerfil(source);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Listo, ya tienes foto de perfil')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InicioViewModel>();
    return MotoCard(
      color: AppColors.primarySurface,
      borderColor: AppColors.primary,
      onTap: vm.subiendoFoto ? null : () => _elegir(context, vm),
      child: Row(
        children: [
          const Icon(Icons.account_circle_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ponte una foto de perfil',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text(
                  'Es obligatoria para ponerte en línea: el cliente ve tu cara '
                  'antes de aceptar tu tarifa, y con foto te aceptan más.',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (vm.subiendoFoto)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
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
    // Tarjeta compacta a propósito: cada píxel que se ahorra aquí se lo lleva
    // el mapa de zonas, que es lo que se estaba quedando fuera de pantalla.
    return MotoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ganancias de hoy',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
          ),
          Text(
            Formato.moneda(vm.gananciasHoy),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
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

/// Dónde han salido pedidos, con datos del backend.
///
/// Antes esto dibujaba tres círculos alrededor del conductor con offsets fijos:
/// parecía información y no lo era. Nunca se pinta un mapa inventado sobre el
/// que alguien podría decidir dónde pararse a esperar.
///
/// El backend ensancha la ventana si en las últimas horas no hubo pedidos (en un
/// municipio de 5 pedidos al día casi nunca los hay) y devuelve cuál usó: el
/// encabezado pinta ese periodo. Solo queda vacío si no hay ni un pedido.
class _ZonasDemanda extends StatelessWidget {
  const _ZonasDemanda({required this.vm, this.alturaMapa});
  final InicioViewModel vm;

  /// Alto del mapa. `null` = toma todo el espacio que le quede a la pantalla
  /// (el caso normal, sin avisos arriba); un valor fijo cuando hay avisos y el
  /// contenido ya excede la pantalla.
  final double? alturaMapa;

  @override
  Widget build(BuildContext context) {
    final d = vm.demanda;
    final mapa = d == null
        ? const SizedBox.shrink()
        : ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints([
                          for (final c in d.celdas) c.centro,
                          if (vm.ubicacion != null) vm.ubicacion!,
                        ]),
                        padding: const EdgeInsets.all(28),
                      ),
                      minZoom: zoomMinimoMapa,
                      maxZoom: zoomMaximoMapa,
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
                              borderColor: _color(
                                c.nivel,
                              ).withValues(alpha: 0.35),
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
                // La leyenda va encima del mapa, no debajo: como fila aparte se
                // llevaba una línea entera de la pantalla y era justo la que
                // quedaba cortada.
                const Positioned(
                  left: AppSpacing.sm,
                  top: AppSpacing.sm,
                  child: _Leyenda(),
                ),
              ],
            ),
          );
    return Column(
      mainAxisSize: alturaMapa == null ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Dónde están pidiendo',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                d != null && d.tieneDatos
                    // El periodo lo decide el servidor: si no hubo pedidos en
                    // las últimas horas, ensancha la ventana. Pintarlo es lo
                    // que evita leer lo de la semana pasada como si fuera ahora.
                    ? '${d.totalPedidos} pedidos · ${d.periodoLabel}'
                    : 'Últimas horas',
                style: const TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 12.5,
                ),
                overflow: TextOverflow.ellipsis,
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
                'Todavía no hay ningún pedido registrado en tu zona. En cuanto '
                'entre el primero, aparece en el mapa.',
          )
        else if (d != null)
          alturaMapa == null
              ? Expanded(child: mapa)
              : SizedBox(height: alturaMapa, child: mapa),
      ],
    );
  }

  static Color _color(NivelDemanda n) => switch (n) {
    NivelDemanda.alta => AppColors.danger,
    NivelDemanda.media => AppColors.warning,
    NivelDemanda.baja => AppColors.success,
  };
}

/// Leyenda de niveles, en una pastilla sobre el mapa.
class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final n in NivelDemanda.values) ...[
            if (n != NivelDemanda.values.first)
              const SizedBox(width: AppSpacing.sm),
            _PuntoLeyenda(color: _ZonasDemanda._color(n), label: n.label),
          ],
        ],
      ),
    );
  }
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

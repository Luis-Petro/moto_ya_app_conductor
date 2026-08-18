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
import '../../../data/services/notificacion_local_service.dart';
import '../../../data/services/ofertas_service.dart';
import '../../../data/services/permisos_service.dart';
import '../../../di/locator.dart';
import '../../../domain/models/demanda_zonas.dart';
import '../../../domain/models/pedido.dart';
import '../../core/format/formato.dart';
import '../../core/tab_activa.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/banner_version.dart';
import '../../core/widgets/beta_chip.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/elegir_foto_sheet.dart';
import '../../core/widgets/estado_badge.dart';
import '../../core/widgets/lugares_layer.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/primary_button.dart';
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
        locator<NotificacionLocalService>(),
        locator<TabActiva>(),
      )..cargar(),
      child: const _InicioView(),
    );
  }
}

class _InicioView extends StatefulWidget {
  const _InicioView();

  @override
  State<_InicioView> createState() => _InicioViewState();
}

class _InicioViewState extends State<_InicioView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// El sistema puede matar el servicio en primer plano con la app minimizada, y
  /// el conductor no se entera: la app sigue diciendo "en línea" mientras el
  /// backend ya lo descartó. Al volver se comprueba y se restablece.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      context.read<InicioViewModel>().alVolverDeSegundoPlano();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InicioViewModel>();

    // Avisos de **puesta a punto de la cuenta**, en el orden en que estorban
    // para trabajar: sin habilitar no hay nada más que hacer; sin foto no se
    // puede uno poner en línea; sin visibilidad no llegan ofertas; la batería
    // solo se lleva las que entran con la app cerrada.
    //
    // Aquí NO entran el pedido en curso ni la oferta —tienen reloj corriendo y
    // no pueden depender de que alguien deslice— ni el interruptor En línea,
    // que es el control de la pantalla y va siempre en el mismo sitio.
    final avisos = <Widget>[
      if (vm.enRevision || vm.rechazado) _RevisionBanner(vm: vm),
      if (!vm.tieneFotoPerfil) const _FotoPerfilBanner(),
      if (vm.sinVisibilidad) const _SinVisibilidadBanner(),
      if (vm.bateria == PermisoBateria.denegado) const _BateriaBanner(),
    ];

    // Los avisos (revisión, foto, pedido activo, oferta) son transitorios pero
    // empujan: con alguno en pantalla el mapa ya no puede quedarse con "lo que
    // sobre" —sobraría casi nada— y pasa a un alto fijo con scroll.
    final hayAvisos =
        vm.enRevision ||
        vm.rechazado ||
        !vm.tieneFotoPerfil ||
        vm.pedidosActivos.isNotEmpty ||
        vm.ofertaActual != null ||
        vm.sinVisibilidad ||
        vm.bateria == PermisoBateria.denegado;
    return Scaffold(
      body: SafeArea(
        child: vm.cargando
            ? SkeletonInicio(
                nombre: vm.nombre,
                iniciales: vm.iniciales,
                fotoUrl: vm.fotoUrl,
              )
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
                          // Los avisos de puesta a punto de la cuenta van en
                          // una sola fila deslizable. Apilados eran cinco
                          // bloques del mismo naranja antes de llegar a nada, y
                          // el conductor nuevo —que es justo quien los tiene
                          // todos— no leía ninguno.
                          //
                          // El orden es por lo que bloquea cada uno, no por
                          // cómo estaban escritos en la pantalla.
                          if (avisos.isNotEmpty) ...[
                            _AvisosCarrusel(avisos: avisos),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          // Una tarjeta por pedido en curso. Con el pedido
                          // encadenado puede llevar más de uno, y el conductor
                          // tiene que poder saltar de uno a otro sin buscarlos
                          // en el historial.
                          for (final p in vm.pedidosActivos) ...[
                            _ActivoBanner(vm: vm, pedido: p),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          // La oferta se muestra AUNQUE ya lleve un pedido. Es
                          // el punto entero del pedido encadenado: si el backend
                          // se la ofreció es porque no quedaba nadie libre y él
                          // va a quedar libre cerca de la nueva recogida.
                          // Ocultarla aquí hacía que esa oferta se venciera sin
                          // que nadie la viera nunca.
                          if (vm.ofertaActual != null) ...[
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.subtitle.copyWith(fontWeight: AppText.fuerte),
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
                    style: AppText.caption,
                  ),
                  if (vm.municipioNombre != null)
                    Flexible(
                      child: Text(
                        ' · ${vm.municipioNombre}',
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
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

/// Los avisos de configuración, en una sola fila deslizable.
///
/// Apilados, un conductor nuevo veía tres o cuatro bloques del mismo naranja
/// —todos necesarios, todos compitiendo— y el mapa de demanda quedaba fuera de
/// la pantalla. En fila se lee uno cada vez y la pantalla vuelve a caber.
///
/// Tres reglas que no son cosméticas:
/// - **Con un solo aviso no hay carrusel**: una tarjeta a lo ancho, como antes.
///   Un carrusel de una página es un carrusel roto.
/// - **No avanza solo.** Cada tarjeta tiene una acción a un toque; una que se
///   mueve sola se pulsa por error.
/// - **Dice cuántos hay.** Con puntos a secas y cuatro tarjetas casi idénticas,
///   nadie sabe si ya las vio todas.
class _AvisosCarrusel extends StatefulWidget {
  const _AvisosCarrusel({required this.avisos});

  final List<Widget> avisos;

  @override
  State<_AvisosCarrusel> createState() => _AvisosCarruselState();
}

class _AvisosCarruselState extends State<_AvisosCarrusel> {
  /// Alto de diseño de una tarjeta compacta (título + dos líneas + acción), a
  /// escala de texto 1. Las tarjetas están redactadas para este alto y lo que no
  /// cabe vive en la pantalla que abren.
  static const _altoBase = 132.0;

  /// La parte del alto que **no** depende del texto: el relleno de `MotoCard`.
  /// Escalarla también engordaría la tarjeta sin que haga falta.
  static const _altoNoEscalable = 2 * AppSpacing.lg;

  /// Alto real de la tarjeta, derivado de la escala de texto del sistema.
  ///
  /// Era una constante, y ese es el desborde clásico: un `PageView` necesita
  /// saber cuánto mide su página, así que con la escala al 130 % el texto de la
  /// tarjeta crecía y la fila no. A escala 1 devuelve exactamente [_altoBase],
  /// así que no cambia nada para quien no toca el tamaño de letra.
  static double _alto(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(_altoBase - _altoNoEscalable) +
      _altoNoEscalable;

  final _controlador = PageController(viewportFraction: 0.92);
  int _pagina = 0;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avisos = widget.avisos;
    if (avisos.length == 1) return avisos.single;

    // Al resolverse un aviso la lista encoge y la página actual puede quedar
    // fuera: sin esto el contador diría "4 de 3".
    final actual = _pagina.clamp(0, avisos.length - 1);

    return Column(
      children: [
        SizedBox(
          height: _alto(context),
          child: PageView.builder(
            controller: _controlador,
            itemCount: avisos.length,
            onPageChanged: (i) => setState(() => _pagina = i),
            itemBuilder: (_, i) => Padding(
              // La tarjeta siguiente asoma por el borde: es lo que hace que
              // alguien deslice sin que nadie se lo explique.
              padding: EdgeInsets.only(
                right: i == avisos.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: avisos[i],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < avisos.length; i++)
              Container(
                width: i == actual ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == actual ? AppColors.primary : AppColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            Text('${actual + 1} de ${avisos.length}', style: AppText.caption),
          ],
        ),
      ],
    );
  }
}

class _ActivoBanner extends StatelessWidget {
  const _ActivoBanner({required this.vm, required this.pedido});
  final InicioViewModel vm;
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    // Con dos pedidos encima, "Pedido en curso" repetido no dice cuál es cuál.
    // El orden no es cosmético: el primero es el que tomó antes y el que
    // normalmente va más adelantado.
    final posicion = vm.pedidosActivos.indexOf(p) + 1;
    final titulo = vm.llevaVariosPedidos
        ? 'Pedido $posicion de ${vm.pedidosActivos.length}'
        : 'Pedido en curso';
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
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subtitle.copyWith(
                    color: Colors.white,
                    fontWeight: AppText.fuerte,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.categoria.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // Token propio y no un blanco translúcido del framework:
                        // sobre el navy hacía falta un secundario y no había
                        // ninguno declarado, así que cada pantalla inventaba el
                        // suyo y la regla de "ningún color suelto" no se podía
                        // aplicar sin excepciones.
                        style: AppText.caption.copyWith(
                          color: AppColors.onAccentMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // El mismo distintivo que el historial y el detalle. Antes
                    // el estado era texto suelto aquí y una pastilla allá, y no
                    // coincidían.
                    EstadoBadge(estado: p.estado),
                  ],
                ),
              ],
            ),
          ),
          Text(
            'Continuar',
            style: AppText.caption.copyWith(
              color: Colors.white,
              fontWeight: AppText.fuerte,
            ),
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
    // Llegar una oferta con un pedido encima es una situación distinta y hay que
    // nombrarla: el conductor tiene que entender que se le suma, no que sustituye
    // al que lleva. Y que puede decir que no sin consecuencias, como siempre.
    final encadenado = vm.pedidoActivo != null;
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
                Text(
                  encadenado
                      ? 'Otro pedido, de camino al tuyo'
                      : '¡Nuevo pedido cerca!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subtitle.copyWith(fontWeight: AppText.fuerte),
                ),
                // La tarifa es el dato sobre el que se decide: va con el rol de
                // dinero de lista, no diluida en la misma línea que la categoría.
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${pedido.categoria.label} · ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                    ),
                    Text(
                      Formato.moneda(pedido.tarifaSugerida),
                      style: AppText.moneySm,
                    ),
                  ],
                ),
                if (encadenado)
                  Text(
                    'Se suma al que llevas. Puedes decir que no.',
                    style: AppText.caption,
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
                  // Es la acción más importante de la app: `title` y no
                  // `subtitle`. Con el peso de una fila de lista competía con
                  // los avisos que tiene encima, que son secundarios.
                  style: AppText.title.copyWith(
                    color: activo ? Colors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bloqueado
                      ? 'Paga tu deuda para recibir pedidos'
                      : noHabilitado
                      ? 'En revisión: aún no puedes recibir pedidos'
                      : (enLinea
                            ? 'Recibiendo pedidos de tu zona'
                            : 'Los pedidos de tu zona se le ofrecen a otros conductores'),
                  style: AppText.caption.copyWith(
                    color: activo ? AppColors.onAccentMuted : AppColors.inkMuted,
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
          'Mientras estés EN LÍNEA, Zumbeo comparte tu ubicación con la plataforma '
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
              'Zumbeo necesita tu ubicación para asignarte pedidos cercanos. '
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
    final source = await elegirFotoSheet(
      context,
      titulo: 'Tu foto de perfil',
      contexto: 'Que se te vea la cara, de frente y con buena luz. Es la que '
          've el cliente al elegir conductor.',
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
            child: _TextoAviso(
              titulo: 'Ponte una foto de perfil',
              detalle: 'Obligatoria para ponerte en línea: es la cara que ve '
                  'el cliente al elegir.',
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

/// Aviso de que el conductor está en línea pero el backend ya no lo ve.
///
/// El reporte de posición falla en silencio: ni el GPS ni la red avisan de que
/// dejaron de funcionar. Sin esta tarjeta el conductor ve el interruptor en «en
/// línea», no le llega ninguna oferta y no tiene forma de saber por qué.
class _SinVisibilidadBanner extends StatelessWidget {
  const _SinVisibilidadBanner();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InicioViewModel>();
    return MotoCard(
      color: AppColors.dangerSurface,
      borderColor: AppColors.danger,
      child: Row(
        children: [
          const Icon(Icons.location_disabled_rounded, color: AppColors.danger),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: _TextoAviso(
              titulo: 'No estás recibiendo pedidos',
              detalle: 'Llevas un rato sin enviar tu ubicación. Revisa el GPS '
                  'y los datos.',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: vm.abrirConfiguracionUbicacion,
            child: const Text('Ajustes'),
          ),
        ],
      ),
    );
  }
}

/// Aviso de que la app está sometida a la optimización de batería.
///
/// En los teléfonos de gama media que dominan el mercado local el sistema mata
/// el proceso al minimizar la app, y sin la exención no llegan ni el push ni el
/// sondeo. **No bloquea nada**: es información y un atajo al diálogo del sistema.
class _BateriaBanner extends StatelessWidget {
  const _BateriaBanner();

  /// La explicación completa, en la hoja que abre la tarjeta.
  ///
  /// En la tarjeta ocupaba dos párrafos —el aviso más largo del Inicio— y aquí
  /// no se puede recortar: lo de "Inicio automático" es la instrucción que más
  /// falta ha hecho en el piloto, y cada marca la esconde en una pantalla
  /// distinta sin API pública para abrirla. Lo único que se puede hacer es
  /// decirle dónde mirar.
  Future<void> _explicar(BuildContext context, InicioViewModel vm) async {
    final permitir = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Te pueden faltar pedidos con la app cerrada',
                style: AppText.title,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tu teléfono puede cerrar Zumbeo para ahorrar batería. Elige '
                '"Permitir" para que los avisos de pedido te lleguen aunque no '
                'tengas la app abierta.',
                style: AppText.body.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Si tienes Xiaomi, Huawei, Oppo o Realme, busca además "Inicio '
                'automático" en los ajustes y actívalo para Zumbeo.',
                style: AppText.body.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Permitir',
                icon: Icons.battery_saver_rounded,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (permitir == true) await vm.pedirExencionBateria();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InicioViewModel>();
    return MotoCard(
      color: AppColors.primarySurface,
      borderColor: AppColors.primary,
      onTap: () => _explicar(context, vm),
      child: Row(
        children: [
          const Icon(Icons.battery_alert_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: _TextoAviso(
              titulo: 'Te pueden faltar pedidos con la app cerrada',
              detalle: 'Tu teléfono puede cerrar Zumbeo para ahorrar batería. '
                  'Toca para permitirlo.',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}

/// Título y detalle de una tarjeta de aviso, redactados para el alto fijo del
/// carrusel: el detalle se corta a dos líneas en vez de estirar la tarjeta y
/// desbordar. Lo que no cabe vive en la pantalla que abre el aviso.
class _TextoAviso extends StatelessWidget {
  const _TextoAviso({required this.titulo, required this.detalle});

  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          // `subtitle`, no `title`: los avisos son secundarios frente al control
          // "En línea", que es lo que el conductor viene a tocar. Cuando todo
          // destaca, no destaca nada.
          style: AppText.subtitle.copyWith(fontWeight: AppText.fuerte),
        ),
        const SizedBox(height: 2),
        Text(
          detalle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption,
        ),
      ],
    );
  }
}

/// Aviso en Inicio cuando la cuenta está en revisión o fue rechazada.
///
/// **Cuando falta un documento, el aviso lleva a subirlo.** Antes decía "estamos
/// revisando tus documentos" incluso si no había ninguno que revisar, y para
/// corregirlo había que salir a Perfil y bajar hasta la fila correcta.
///
/// Con los cuatro subidos no hay botón: no hay nada que corregir, y uno que
/// llevara a una lista completa sería una visita en vano.
class _RevisionBanner extends StatelessWidget {
  const _RevisionBanner({required this.vm});
  final InicioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final rechazado = vm.rechazado;
    final faltantes = vm.conductor?.documentosFaltantes ?? const <String>[];
    // Rechazado siempre ofrece la salida: aunque estén los cuatro, hay algo que
    // reemplazar — es justo lo que significa que te rechacen.
    final puedeCorregir = rechazado || faltantes.isNotEmpty;

    return MotoCard(
      color: rechazado ? AppColors.dangerSurface : AppColors.primarySurface,
      borderColor: rechazado ? AppColors.danger : AppColors.primary,
      // La acción entera es la tarjeta, no un botón debajo: en el carrusel el
      // alto es fijo y una fila de botón no cabe. Sigue siendo un toque.
      onTap: puedeCorregir ? () => context.push(Rutas.documentos) : null,
      child: Row(
        children: [
          Icon(
            rechazado ? Icons.error_outline : Icons.hourglass_top_rounded,
            color: rechazado ? AppColors.danger : AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _TextoAviso(
              titulo: rechazado ? 'Cuenta rechazada' : 'Cuenta en revisión',
              detalle: _mensaje(rechazado, faltantes),
            ),
          ),
          if (puedeCorregir) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.upload_file_rounded,
              color: rechazado ? AppColors.danger : AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }

  String _mensaje(bool rechazado, List<String> faltantes) {
    if (rechazado) {
      final motivo = vm.motivoRechazo?.trim() ?? '';
      return motivo.isNotEmpty
          ? motivo
          : 'Tus documentos fueron rechazados. Vuelve a subirlos para que te revisemos.';
    }
    if (faltantes.isEmpty) {
      return 'Estamos revisando tus documentos. Te habilitaremos para recibir '
          'pedidos muy pronto.';
    }
    // Nombrar lo que falta: "en revisión" a secas deja esperando a quien todavía
    // no ha aportado nada, y la espera nunca termina.
    return faltantes.length == 1
        ? 'Nos falta tu ${faltantes.first} para poder revisarte.'
        : 'Nos faltan ${faltantes.length} documentos: ${faltantes.join(', ')}.';
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
          // Etiqueta encima y pequeña, cifra debajo y grande. En la misma línea
          // competían, y el número es lo único que hay que leer aquí.
          const Text('Ganancias de hoy', style: AppText.caption),
          Text(Formato.moneda(vm.gananciasHoy), style: AppText.money),
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
    // Etiqueta arriba y cifra abajo, igual que las ganancias: la misma regla en
    // los dos sitios, o la tarjeta cuenta dos historias distintas.
    return Column(
      children: [
        Text(etiqueta, style: AppText.caption),
        Text(
          valor,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.moneySm,
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

  /// El área del mapa.
  ///
  /// Antes esto era una variable calculada al principio del `build`, así que se
  /// construía **siempre que `demanda != null`** — incluso cuando la rama de
  /// "todavía no hay pedidos" la descartaba. Y ese es justo el caso en que
  /// `LatLngBounds.fromPoints` recibía la lista vacía y lanzaba. Que sea un
  /// método y se llame solo desde su rama es lo que lo hace imposible;
  /// [encuadreDePuntos] es el cinturón.
  Widget _mapa(DemandaZonas d) => ClipRRect(
    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    child: Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            options: MapOptions(
              initialCameraFit: encuadreDePuntos([
                for (final c in d.celdas) c.centro,
                if (vm.ubicacion != null) vm.ubicacion!,
              ]),
              minZoom: zoomMinimoMapa,
              maxZoom: zoomMaximoMapa,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              osmTileLayer(),
              // Las manchas de demanda dicen "por aquí se pide"; los
              // lugares dicen dónde es "por aquí". Una mancha sobre
              // calles sin nombre no le sirve para decidir dónde
              // pararse a esperar.
              const LugaresLayer(),
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

  /// Da al hijo el alto del área del mapa: todo lo que quede de pantalla cuando
  /// no hay avisos arriba, o el alto fijo cuando sí los hay.
  Widget _conAltoDeMapa(Widget hijo) => alturaMapa == null
      ? Expanded(child: hijo)
      : SizedBox(height: alturaMapa, child: hijo);

  @override
  Widget build(BuildContext context) {
    final d = vm.demanda;

    return Column(
      mainAxisSize: alturaMapa == null ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Dónde están pidiendo',
              style: AppText.subtitle.copyWith(fontWeight: AppText.fuerte),
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
                style: AppText.caption,
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
        // La consulta de demanda es la más lenta del Inicio: el backend ensancha
        // la ventana (2 h → 24 h → 7 d → 30 d → 1 año → todo) hasta juntar cinco
        // pedidos. Sin esta rama, `demanda == null` con la consulta en vuelo no
        // caía en ninguna de las tres de abajo y dejaba medio alto de pantalla en
        // blanco — que es la mitad del reporte de "el home queda en blanco".
        // Va condicionada a `d == null` a propósito: al refrescar con datos ya en
        // pantalla, cambiar el mapa por un esqueleto sería un paso atrás (para eso
        // está el indicador pequeño del encabezado).
        if (d == null && vm.cargandoDemanda)
          _conAltoDeMapa(
            const Skeleton(
              height: double.infinity,
              radius: AppSpacing.radiusMd,
            ),
          )
        else if (d == null)
          _AvisoDemanda(
            icono: Icons.cloud_off_outlined,
            texto: 'No pudimos cargar las zonas de demanda.',
            accion: vm.cargarDemanda,
          )
        else if (!d.tieneDatos)
          const _AvisoDemanda(
            icono: Icons.query_stats_outlined,
            texto:
                'Todavía no hay ningún pedido registrado en tu zona. En cuanto '
                'entre el primero, aparece en el mapa.',
          )
        else
          _conAltoDeMapa(_mapa(d)),
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
        // Flota sobre el mapa: tiene que leerse igual sobre una calle blanca
        // que sobre una zona verde, y el borde solo no lo consigue.
        boxShadow: AppElevation.flotante,
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
        Text(label, style: AppText.caption),
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
            child: Text(texto, style: AppText.body),
          ),
          if (accion != null)
            TextButton(onPressed: accion, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

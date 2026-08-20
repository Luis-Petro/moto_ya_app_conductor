import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/services/app_version_service.dart';
import '../../../data/services/banner_descartes.dart';
import '../../../data/services/banner_image_store.dart';
import '../../../data/services/banner_service.dart';
import '../../../di/locator.dart';
import '../../../domain/models/banner_app.dart';
import '../navegacion/observador_de_regreso.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'banner_version.dart';

/// Proporción de la caja de avisos, la misma que el backend exige a cada imagen
/// que se sube desde el panel.
///
/// Es lo que hace **imposible** que un banner rompa el layout: la altura sale
/// del ancho de la pantalla y de esta constante, nunca de las dimensiones del
/// archivo que llegó.
const double kRatioBanner = 16 / 6;

/// Cada cuánto pasa al siguiente aviso mientras nadie lo toca.
const Duration _intervaloAvance = Duration(seconds: 6);

/// Un aviso del carrusel: o la versión nueva, o un banner del panel.
class _Aviso {
  const _Aviso.version(this.version)
      : banner = null,
        bytes = null;

  const _Aviso.banner(this.banner, this.bytes) : version = null;

  final VersionVigente? version;
  final BannerApp? banner;
  final Uint8List? bytes;

  /// Clave estable para `PageView`: la versión no tiene id numérico.
  Object get clave => banner?.id ?? 'version';

  /// Identidad para comparar dos cargas: **todo lo que se pinta**.
  ///
  /// No basta con el id y la publicación, y esto fue un fallo real. Editar un
  /// banner **no** sella `publicadoEn` —ni debe hacerlo: una errata no es un
  /// aviso nuevo y no puede reaparecer en la cara de quien ya lo cerró—, así que
  /// reemplazar la imagen o corregir el texto daba la misma firma, la recarga
  /// decidía que no había nada que repintar y la app viva seguía enseñando lo
  /// viejo hasta que alguien matara el proceso. Los bytes nuevos se bajaban y se
  /// tiraban.
  ///
  /// Son dos preguntas distintas y llevan dos respuestas distintas:
  /// `BannerApp.claveDescarte` responde "¿es otra publicación?" y esto responde
  /// "¿cambió lo que se ve?".
  String get firma {
    final b = banner;
    if (b == null) return 'v:${version!.version}';
    return [
      b.id,
      b.publicadoEn?.millisecondsSinceEpoch ?? '',
      b.imagenUrl,
      b.textoAlternativo,
      b.enlaceUrl ?? '',
      b.descartable,
    ].join('|');
  }
}

/// Franja de avisos del Inicio: la versión nueva (siempre primera) y los banners
/// que el administrador publica desde el panel.
///
/// Con un solo aviso se pinta fijo, sin indicadores ni movimiento. Con ninguno
/// **ocupa cero**: nada de un hueco reservado esperando a que alguien publique.
///
/// Cualquier fallo —la consulta, una imagen que no baja— se resuelve quitando
/// ese aviso, nunca con un error en pantalla: esta franja no puede estorbar el
/// uso normal de la app. En esta app eso importa el doble, porque justo debajo
/// van los avisos de la cuenta del conductor, que sí bloquean su trabajo.
///
/// **Se refresca sin reiniciar la app**, por tres hechos: al volver del segundo
/// plano, al volver a esta pestaña y al cerrarse una pantalla abierta encima del
/// shell (`ObservadorDeRegreso`). Cargar solo en `initState` significaba que un
/// banner publicado ahora no se veía hasta que alguien matara la app y la abriera
/// de nuevo, y eso es pedirle al usuario que haga algo para arreglar algo
/// nuestro. Sin temporizador: esto cambia dos veces por semana y el sondeo lo
/// pagarían en datos y batería todas las instalaciones.
class CarruselBanners extends StatefulWidget {
  const CarruselBanners({super.key});

  @override
  State<CarruselBanners> createState() => _CarruselBannersState();
}

class _CarruselBannersState extends State<CarruselBanners> with WidgetsBindingObserver {
  final PageController _controller = PageController();
  final List<_Aviso> _avisos = [];
  Timer? _avance;
  int _actual = 0;

  /// El avance automático se apaga con el primer gesto y **no vuelve**: mover la
  /// vista bajo el dedo de alguien que está leyendo es peor que no rotar.
  bool _tocado = false;

  /// El aviso de versión se descarta por sesión, así que un refresco no puede
  /// devolverlo a la pantalla de quien acaba de cerrarlo.
  bool _versionDescartada = false;

  /// Ids de la última respuesta del servidor, para poder depurar los descartes
  /// de banners que ya no existen.
  Set<int> _idsVigentes = const {};

  /// Evita que dos cargas se pisen (volver del segundo plano y de la pestaña a la vez).
  bool _cargando = false;

  /// Si esta rama del shell está visible. `TickerMode` es lo que `go_router`
  /// apaga en las pestañas que no se ven, así que sirve de señal de "volví".
  bool _enPantalla = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ObservadorDeRegreso.regresos.addListener(_alVolverDeOtraPantalla);
    _cargar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (visible && !_enPantalla) {
      _cargar();
    }
    _enPantalla = visible;
  }

  /// Se cerró una pantalla de encima del shell (el alta, un pedido, el feedback).
  /// `TickerMode` no se entera de esto: esas pantallas se empujan en el navigator
  /// raíz y la rama del Inicio nunca deja de estar activa.
  ///
  /// Solo recarga si esta pestaña es la que se ve. Si se volvió a otra, su propio
  /// `TickerMode` lo hará cuando el conductor venga aquí, y adelantarse sería una
  /// consulta que nadie va a mirar.
  void _alVolverDeOtraPantalla() {
    if (_enPantalla) {
      _cargar();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ObservadorDeRegreso.regresos.removeListener(_alVolverDeOtraPantalla);
    _avance?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Trae los avisos y los pinta.
  ///
  /// La lista nueva se construye **entera** —bytes incluidos, que la caché de
  /// disco sirve sin red— antes de tocar el estado, y si resulta idéntica a la
  /// que ya se ve no se toca nada: así un refresco no parpadea ni devuelve el
  /// carrusel a la primera tarjeta mientras alguien lee la tercera. Un fallo
  /// deja en pantalla lo que hubiera.
  Future<void> _cargar() async {
    if (_cargando) return;
    _cargando = true;
    try {
      final version = await locator<AppVersionService>().nuevaVersionDisponible();
      final banners = await locator<BannerService>().vigentes();
      // La consulta falló: se deja en pantalla lo que hubiera. Vaciar la franja
      // porque el teléfono se quedó sin cobertura sería castigar al usuario por
      // algo que no hizo.
      if (banners == null) return;
      final descartados = await locator<BannerDescartes>().descartados();

      final avisos = <_Aviso>[
        if (version != null && !_versionDescartada) _Aviso.version(version),
      ];
      final store = locator<BannerImageStore>();
      for (final b in banners) {
        final clave = b.claveDescarte;
        if (clave != null && descartados.contains(clave)) continue;
        final bytes = await store.bytes(b.imagenUrl);
        // Una imagen que no llega se queda fuera **antes** de construir el
        // carrusel: dentro, los indicadores contarían un aviso que no se ve.
        if (bytes == null) continue;
        avisos.add(_Aviso.banner(b, bytes));
      }

      if (!mounted) return;
      _idsVigentes = {for (final b in banners) b.id};
      if (_mismosQueSeVen(avisos)) return;
      setState(() {
        _avisos
          ..clear()
          ..addAll(avisos);
        if (_actual >= _avisos.length) {
          _actual = _avisos.isEmpty ? 0 : _avisos.length - 1;
        }
      });
      _programarAvance();
    } finally {
      _cargando = false;
    }
  }

  bool _mismosQueSeVen(List<_Aviso> nuevos) {
    if (nuevos.length != _avisos.length) return false;
    for (var i = 0; i < nuevos.length; i++) {
      if (nuevos[i].firma != _avisos[i].firma) return false;
    }
    return true;
  }

  void _programarAvance() {
    _avance?.cancel();
    if (_tocado || _avisos.length < 2) return;
    // Quien pide animaciones reducidas en el sistema está pidiendo justo esto.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _avance = Timer.periodic(_intervaloAvance, (_) {
      if (!mounted || _avisos.length < 2) return;
      final siguiente = (_actual + 1) % _avisos.length;
      _controller.animateToPage(
        siguiente,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  void _detenerAvance() {
    _tocado = true;
    _avance?.cancel();
    _avance = null;
  }

  Future<void> _descartar(_Aviso aviso) async {
    final banner = aviso.banner;
    if (banner == null) {
      _versionDescartada = true;
    } else {
      final clave = banner.claveDescarte;
      if (clave != null) {
        await locator<BannerDescartes>().descartar(clave, idsVigentes: _idsVigentes);
      }
    }
    if (!mounted) return;
    setState(() {
      _avisos.remove(aviso);
      if (_actual >= _avisos.length) {
        _actual = _avisos.isEmpty ? 0 : _avisos.length - 1;
      }
    });
    if (_avisos.length < 2) _detenerAvance();
  }

  Future<void> _abrir(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_avisos.isEmpty) return const SizedBox.shrink();
    final unico = _avisos.length == 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final alto = constraints.maxWidth / kRatioBanner;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: alto,
                child: unico
                    ? _tarjeta(_avisos.first)
                    : Listener(
                        onPointerDown: (_) => _detenerAvance(),
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: _avisos.length,
                          onPageChanged: (i) => setState(() => _actual = i),
                          itemBuilder: (context, i) => _tarjeta(_avisos[i]),
                        ),
                      ),
              ),
              if (!unico) ...[
                const SizedBox(height: AppSpacing.xs),
                _Puntos(total: _avisos.length, actual: _actual),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _tarjeta(_Aviso aviso) {
    final version = aviso.version;
    if (version != null) {
      return TarjetaVersion(nueva: version, onDescartar: () => _descartar(aviso));
    }
    return _TarjetaBanner(
      banner: aviso.banner!,
      bytes: aviso.bytes!,
      onAbrir: _abrir,
      onDescartar: () => _descartar(aviso),
    );
  }
}

/// Imagen del banner dentro de la caja de proporción fija.
///
/// `BoxFit.cover` no recorta nada en la práctica: la proporción se validó al
/// subir la imagen. Está ahí para que un archivo inesperado se salga de la caja
/// en vez de deformarse o desbordar la pantalla.
class _TarjetaBanner extends StatelessWidget {
  const _TarjetaBanner({
    required this.banner,
    required this.bytes,
    required this.onAbrir,
    required this.onDescartar,
  });

  final BannerApp banner;
  final Uint8List bytes;
  final Future<void> Function(String url) onAbrir;
  final VoidCallback onDescartar;

  @override
  Widget build(BuildContext context) {
    final enlace = banner.enlaceUrl;
    final imagen = ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        semanticLabel: banner.textoAlternativo,
        gaplessPlayback: true,
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Sin enlace no hay `onTap` ni efecto de toque: un aviso que parece
        // pulsable y no hace nada se toca dos veces y se desconfía a la tercera.
        if (enlace == null)
          imagen
        else
          Semantics(
            button: true,
            label: banner.textoAlternativo,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                onTap: () => onAbrir(enlace),
                child: imagen,
              ),
            ),
          ),
        if (banner.descartable)
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: AppColors.ink.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Descartar',
                onPressed: onDescartar,
                iconSize: 18,
                color: Colors.white,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
      ],
    );
  }
}

/// Indicadores de posición. Solo aparecen con más de un aviso: con uno solo
/// serían un punto que no dice nada.
class _Puntos extends StatelessWidget {
  const _Puntos({required this.total, required this.actual});

  final int total;
  final int actual;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Aviso ${actual + 1} de $total',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final activo = i == actual;
          return Container(
            width: activo ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: activo ? AppColors.primary : AppColors.line,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

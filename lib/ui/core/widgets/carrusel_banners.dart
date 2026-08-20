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
}

/// Franja de avisos del Inicio: la versión nueva (siempre primera) y los banners
/// que el administrador publica desde el panel.
///
/// Con un solo aviso se pinta fijo, sin indicadores ni movimiento. Con ninguno
/// **ocupa cero**: nada de un hueco reservado esperando a que alguien publique.
/// En esta app eso importa el doble, porque justo debajo van los avisos de la
/// cuenta del conductor, que sí bloquean su trabajo.
///
/// Cualquier fallo —la consulta, una imagen que no baja— se resuelve quitando
/// ese aviso, nunca con un error en pantalla: esta franja no puede estorbar el
/// uso normal de la app.
class CarruselBanners extends StatefulWidget {
  const CarruselBanners({super.key});

  @override
  State<CarruselBanners> createState() => _CarruselBannersState();
}

class _CarruselBannersState extends State<CarruselBanners> {
  final PageController _controller = PageController();
  final List<_Aviso> _avisos = [];
  Timer? _avance;
  int _actual = 0;

  /// El avance automático se apaga con el primer gesto y **no vuelve**: mover la
  /// vista bajo el dedo de alguien que está leyendo es peor que no rotar.
  bool _tocado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _avance?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final version = await locator<AppVersionService>().nuevaVersionDisponible();
    final banners = await locator<BannerService>().vigentes();
    final descartados = await locator<BannerDescartes>().descartados();

    final avisos = <_Aviso>[
      if (version != null) _Aviso.version(version),
    ];
    final store = locator<BannerImageStore>();
    for (final b in banners) {
      if (descartados.contains(b.id)) continue;
      final bytes = await store.bytes(b.imagenUrl);
      // Una imagen que no llega se queda fuera **antes** de construir el
      // carrusel: dentro, los indicadores contarían un aviso que no se ve.
      if (bytes == null) continue;
      avisos.add(_Aviso.banner(b, bytes));
    }

    if (!mounted) return;
    setState(() {
      _avisos
        ..clear()
        ..addAll(avisos);
    });
    _programarAvance();
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
    if (banner != null) {
      await locator<BannerDescartes>().descartar(banner.id);
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

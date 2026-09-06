import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../data/repositories/usuario_repository.dart';
import '../../../data/services/lugar_service.dart';
import '../../../di/locator.dart';
import '../../../domain/models/lugar.dart';
import '../navegacion/observador_de_regreso.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'lugar_marcadores.dart';

/// Capa del catálogo de lugares para cualquier `FlutterMap`.
///
/// Va como hijo del mapa, **por encima** de lo que sea relleno translúcido y por
/// debajo de los marcadores del pedido:
///
/// ```dart
/// children: [
///   osmTileLayer(),
///   CircleLayer(circles: [...]),  // zonas de demanda
///   const LugaresLayer(),
///   MarkerLayer(markers: [...]),  // recogida, entrega, mi posición
/// ]
/// ```
///
/// Lee el zoom de la cámara del mapa que la contiene (`MapCamera.of`), así que
/// se repinta sola al acercar y la pantalla no tiene que seguir la cámara.
///
/// **Para el conductor esto no es decoración, es la nomenclatura del pueblo.**
/// Las calles del municipio no tienen nombre ni número en el mapa; lo que le
/// dice dónde está es la plaza, la droguería y el D1. Y el catálogo lo alimenta
/// él mismo: cada lugar que propone se lo encuentra dibujado la próxima vez.
///
/// Los lugares que son un **área** (el parque, el polideportivo, la cancha) se
/// dibujan además como polígono debajo de los marcadores. "Te espero en el
/// parque" deja de ser un pin flotando en medio de la nada.
///
/// > **Su gemela vive en `app_cliente/lib/ui/core/widgets/lugares_layer.dart` y
/// > las dos se mueven juntas.** No hay dependencia entre ellas —las dos apps se
/// > construyeron por copy-then-adapt y comparten decenas de archivos por
/// > convención—, así que un arreglo aquí hay que llevarlo allí a mano, y al
/// > revés. Esta capa **es** el resultado de no haberlo hecho: la de cliente
/// > aprendió a recuperarse en 2026-09 y esta se quedó con el fallo un mes más.
class LugaresLayer extends StatefulWidget {
  const LugaresLayer({
    super.key,
    this.municipioId,
    this.onTap,
    this.mostrarNombres = true,
    this.recargarAlReaparecer = false,
    this.opacidad = 1,
  });

  /// Municipio del catálogo. Si es `null` se resuelve el del usuario.
  final int? municipioId;

  /// Qué hacer al tocar un lugar. En los mapas de solo lectura no se pasa: los
  /// lugares son referencia visual y tocarlos no debe hacer nada.
  final ValueChanged<Lugar>? onTap;

  /// Si se permite la etiqueta con el nombre al acercar. Se apaga en los mapas
  /// pequeños del pedido (150–220 px): ahí las etiquetas tapan la ruta, que es
  /// justo lo que esa pantalla va a mostrar.
  final bool mostrarNombres;

  /// Si esta capa vuelve a pedir el catálogo cuando su pantalla reaparece.
  ///
  /// **Nace apagado y hoy solo lo enciende el mapa del Inicio**, que es la única
  /// pantalla con mapa que no se desmonta nunca: vive en el
  /// `StatefulShellRoute.indexedStack`, así que su `initState` es el único
  /// intento de toda la sesión y cae siempre en el arranque en frío de la app.
  /// Si sale mal, el mapa se queda mudo hasta que alguien mate la app. Las demás
  /// pantallas con mapa son rutas empujadas: cada apertura crea un `State` nuevo
  /// y vuelve a intentarlo sola, así que encenderlo ahí serían recargas que
  /// nadie pidió y ni siquiera registran los oyentes.
  final bool recargarAlReaparecer;

  /// Cuánto se ve esta capa, de 0 a 1. Hoy nadie la baja en esta app; existe por
  /// paridad con la de cliente, que la atenúa en el mapa de seguimiento.
  final double opacidad;

  @override
  State<LugaresLayer> createState() => _LugaresLayerState();
}

/// En qué acabó el último intento. Los cuatro producen el mismo píxel —un mapa
/// sin marcadores— y hasta ahora eran indistinguibles también por dentro.
enum _Desenlace { pendiente, lugares, vacio, fallo }

class _LugaresLayerState extends State<LugaresLayer>
    with WidgetsBindingObserver {
  List<Lugar> _lugares = const [];

  /// Esperas entre reintentos, escalonadas.
  ///
  /// Antes era **un solo reintento a los 2 segundos**, y eso no es un arreglo:
  /// es una moneda al aire. Si el perfil del usuario tardaba 2,5 segundos —una
  /// red de municipio, un arranque en frío, un teléfono lento—, la capa se
  /// rendía para siempre y el mapa salía sin un solo marcador, sin error y sin
  /// nada que reintentar. En el Inicio del conductor el perfil se pide con
  /// `unawaited`, así que esa carrera se pierde a diario: es el "a veces carga
  /// y a veces no".
  ///
  /// Escalonado y acotado: insiste unos quince segundos y para. Con
  /// [LugaresLayer.recargarAlReaparecer] encendido, pararse ya no significa
  /// rendirse para siempre: la escalera vuelve a su primer peldaño cada vez que
  /// la pantalla reaparece.
  static const _esperas = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 4),
    Duration(seconds: 5),
  ];

  /// Tras cuántos fallos de la consulta se ofrece reintentar a mano.
  ///
  /// Tres y no los cinco de la escalera: los cinco pasos gastan unos quince
  /// segundos antes de rendirse, y a los seis (1+2+3) ya se sabe que algo va
  /// mal. Los intentos que queden siguen corriendo por debajo; si uno acierta,
  /// el enlace se va solo.
  static const _fallosParaOfrecerReintento = 3;

  /// Cuánto se espera antes de volver a pedir el municipio.
  ///
  /// **La espera del municipio conserva su propio contador**, separado de la
  /// escalera de fallos del catálogo de arriba: esperar un dato que no llegó y
  /// reintentar una consulta que falló son dos causas distintas, y mezclarlas es
  /// lo que dejaba la capa rendida **sin haber preguntado ni una vez** al
  /// servidor.
  ///
  /// Lo que cambió es quién insiste. Antes esto miraba `enCache` treinta veces
  /// en treinta segundos **sin pedir nada**, esperando a que otra pantalla
  /// llenara la caché. Ahora `UsuarioRepository.resolverMunicipio()` lo **pide**,
  /// con su propio presupuesto de 20 s, así que aquí bastan un par de vueltas
  /// más por si el perfil llega por otro camino.
  static const _esperaMunicipio = Duration(seconds: 5);

  /// Cuántas veces se vuelve a pedir el municipio antes de dejar de insistir.
  static const _reintentosDeMunicipio = 3;

  int _intento = 0;
  Timer? _reintento;

  /// Cuántas veces se ha pedido el municipio sin conseguirlo.
  int _esperasDeMunicipio = 0;

  /// Cuántas veces falló la consulta del catálogo. No cuenta el municipio que
  /// aún no ha llegado: eso no es un fallo y no lo arregla volver a tocar.
  int _fallos = 0;
  bool _ofrecerReintento = false;

  /// En qué acabó el último intento, para poder trazarlo y para distinguir por
  /// dentro lo que por fuera se ve igual.
  _Desenlace _desenlace = _Desenlace.pendiente;

  /// Qué intento es el vigente.
  ///
  /// **Es un contador y no un booleano de "hay uno en curso"**, y la diferencia
  /// es justo lo que se viene a arreglar: con un booleano que bloquee, un
  /// intento que no vuelve deja la pantalla sin poder intentarlo otra vez, que
  /// es el problema del que nace todo esto. Aquí una recarga lanza siempre un
  /// intento nuevo y la respuesta del anterior, si llega tarde, se descarta.
  int _generacion = 0;

  /// Si la rama del shell donde vive esta capa está a la vista. `TickerMode` es
  /// lo que `go_router` apaga en las pestañas que no se ven, así que sirve de
  /// señal de "volví" — la misma que usa la franja de avisos de arriba.
  bool _enPantalla = true;

  @override
  void initState() {
    super.initState();
    if (widget.recargarAlReaparecer) {
      WidgetsBinding.instance.addObserver(this);
      ObservadorDeRegreso.regresos.addListener(_alVolverDeOtraPantalla);
    }
    _cargar(motivo: 'montaje');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.recargarAlReaparecer) return;
    // Leer `TickerMode` solo con la recarga encendida: con ella apagada esta
    // capa no se suscribe a nada y las demás pantallas no pagan ni un rebuild
    // de más.
    final visible = TickerMode.of(context);
    if (visible && !_enPantalla) {
      _cargar(motivo: 'volvió a la pestaña');
    }
    _enPantalla = visible;
  }

  /// Se cerró una pantalla empujada **encima** del shell (el pedido activo, la
  /// entrega, el alta).
  ///
  /// `TickerMode` no se entera de esto: esos flujos van con
  /// `parentNavigatorKey: rootKey` y la rama del Inicio nunca deja de estar
  /// activa mientras están abiertos. Solo recarga si esta pestaña es la que se
  /// ve; si se volvió a otra, su `TickerMode` lo hará cuando el usuario venga.
  void _alVolverDeOtraPantalla() {
    if (_enPantalla) _cargar(motivo: 'se cerró una pantalla encima');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargar(motivo: 'volvió del segundo plano');
    }
  }

  @override
  void didUpdateWidget(covariant LugaresLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.municipioId != oldWidget.municipioId) {
      _cargar(motivo: 'cambió el municipio');
    }
  }

  @override
  void dispose() {
    if (widget.recargarAlReaparecer) {
      WidgetsBinding.instance.removeObserver(this);
      ObservadorDeRegreso.regresos.removeListener(_alVolverDeOtraPantalla);
    }
    _reintento?.cancel();
    super.dispose();
  }

  /// Programa otro intento, si quedan. Con un `Timer` cancelable y no con un
  /// `await` suelto: al salir de la pantalla, el `await` seguía vivo y volvía
  /// sobre un `State` ya desmontado.
  void _reintentar() {
    if (_intento >= _esperas.length) return;
    final espera = _esperas[_intento];
    _intento++;
    _reintento?.cancel();
    _reintento = Timer(espera, () {
      if (mounted) _intentar(motivo: 'reintento automático');
    });
  }

  /// El municipio no se pudo resolver: se ofrece la salida y se vuelve a
  /// intentar, si quedan vueltas.
  ///
  /// El enlace aparece **al primer intento fallido** y no al cabo de medio
  /// minuto: para cuando `resolverMunicipio` devuelve nulo, ya insistió sus
  /// 20 segundos pidiéndolo de verdad. Callarse más tiempo solo alarga el mapa
  /// mudo.
  void _sinMunicipio() {
    if (!mounted) return;
    if (!_ofrecerReintento) {
      setState(() => _ofrecerReintento = true);
    }
    if (_esperasDeMunicipio >= _reintentosDeMunicipio) return;
    _esperasDeMunicipio++;
    _reintento?.cancel();
    _reintento = Timer(_esperaMunicipio, () {
      if (mounted) _intentar(motivo: 'reintento del municipio');
    });
  }

  /// Arranca un intento **nuevo**: devuelve las dos escaleras a su primer
  /// peldaño y pide. Toda señal de fuera —montaje, regreso a la pantalla,
  /// cambio de municipio, reintento manual— entra por aquí.
  void _cargar({required String motivo}) {
    _intento = 0;
    _esperasDeMunicipio = 0;
    _fallos = 0;
    _reintento?.cancel();
    unawaited(_intentar(motivo: motivo));
  }

  Future<void> _intentar({required String motivo}) async {
    final generacion = ++_generacion;
    // Se **pide**, no se mira a ver si alguien lo trajo. Mirar la caché
    // convertía los marcadores en una carrera contra el `unawaited` con el que
    // el Inicio pide el perfil: si esta capa se montaba primero, nadie llenaba
    // la caché a tiempo y no salían nunca, ni siquiera al reintentar a mano. El
    // repositorio comparte un solo intento entre todas las capas que pregunten
    // a la vez.
    final municipioId = widget.municipioId ??
        await locator<UsuarioRepository>().resolverMunicipio();
    if (!_vigente(generacion)) return;
    if (municipioId == null) {
      _desenlace = _Desenlace.fallo;
      _trazar(motivo, 'sin municipio');
      _sinMunicipio();
      return;
    }
    _esperasDeMunicipio = 0;
    final lugares = await locator<LugarService>().catalogoDeMapa(municipioId);
    if (!_vigente(generacion)) return;
    if (lugares == null) {
      // Falló la consulta. Se reintenta con la misma escalera; el motivo ya
      // quedó en el log del servicio y el mapa sin marcadores sigue sirviendo.
      _desenlace = _Desenlace.fallo;
      _fallos++;
      _trazar(motivo, 'falló', municipioId: municipioId);
      if (_fallos >= _fallosParaOfrecerReintento && !_ofrecerReintento) {
        setState(() => _ofrecerReintento = true);
      }
      _reintentar();
      return;
    }
    // Llegó el catálogo. Si estaba vacío, está vacío de verdad: el servicio
    // distingue "no hay lugares" (lista) de "no se pudo traer" (null), y no hay
    // nada que reintentar en el primer caso. Un vacío **no** cuenta en la
    // escalera ni enciende la píldora — pero sí es un desenlace, y ahora se
    // distingue por dentro de "sigo esperando".
    _reintento?.cancel();
    _fallos = 0;
    _desenlace = lugares.isEmpty ? _Desenlace.vacio : _Desenlace.lugares;
    _trazar(motivo, lugares.isEmpty ? 'vacío' : 'llegó',
        municipioId: municipioId, lugares: lugares.length);
    // Con el catálogo vacío solo hay que repintar si había algo pintado (cambio
    // de municipio) o si estaba la píldora puesta. `_lugares.isEmpty` no sobra:
    // sin él, cambiar a un municipio sin lugares conservaba los marcadores del
    // anterior.
    if (lugares.isEmpty && !_ofrecerReintento && _lugares.isEmpty) return;
    setState(() {
      _lugares = lugares;
      _ofrecerReintento = false;
    });
  }

  /// Si este intento sigue siendo el vigente. Una respuesta de un intento
  /// anterior —el que se quedó esperando cuando el usuario volvió a la
  /// pantalla— no puede pintar nada ni tocar los contadores.
  bool _vigente(int generacion) => mounted && generacion == _generacion;

  /// Una línea por intento, con prefijo estable y con **qué lo disparó**.
  ///
  /// Sale también en un APK de release. Es lo que faltaba para poder decir, ante
  /// un "a veces no cargan los sitios", cuál de los cuatro desenlaces ocurrió:
  /// desde fuera los cuatro son el mismo mapa sin marcadores.
  void _trazar(String motivo, String desenlace,
      {int? municipioId, int? lugares}) {
    final municipio = municipioId == null ? '' : ' · municipio $municipioId';
    final cuenta = lugares == null ? '' : ' · $lugares lugares';
    debugPrint('LugaresLayer: $motivo · $desenlace$municipio$cuenta');
  }

  /// Reintento a mano. Vuelve a pedir **de verdad** lo que falte: el perfil si
  /// el municipio nunca llegó, el catálogo si la consulta falló (el servicio no
  /// cachea los fallos). Devuelve las dos escaleras a su primer paso.
  ///
  /// Que pida y no relea es la diferencia entre un enlace y un adorno: mientras
  /// esto miraba la caché del usuario, tocarlo no podía cambiar el resultado.
  void _reintentarAMano() {
    setState(() => _ofrecerReintento = false);
    _cargar(motivo: 'reintento manual');
  }

  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.of(context).zoom;
    if (_lugares.isEmpty || zoom < zoomMinimoLugares) {
      // Se ofrece solo donde los marcadores se verían: reintentar y que no
      // aparezca nada porque el zoom está lejos parece que el reintento falló.
      // Y solo cuando el desenlace fue un **fallo**: un municipio sin lugares y
      // un intento que sigue en curso también dejan el mapa sin marcadores, y
      // ofrecer "reintentar" en esos dos casos es prometer algo que no va a
      // pasar.
      if (_ofrecerReintento &&
          _desenlace == _Desenlace.fallo &&
          zoom >= zoomMinimoLugares) {
        return Positioned.fill(child: _AvisoReintento(onTap: _reintentarAMano));
      }
      return const SizedBox.shrink();
    }
    final marcadores = MarkerLayer(
      markers: marcadoresDeLugares(
        _lugares,
        zoom: zoom,
        onTap: widget.onTap,
        permitirNombres: widget.mostrarNombres,
      ),
    );
    final poligonos = poligonosDeLugares(_lugares);
    // Las áreas van debajo de los marcadores, para que ningún relleno tape un
    // pin. `Positioned.fill` da a las dos capas el mismo tamaño exacto que
    // tendrían como hijas directas del mapa.
    final capa = poligonos.isEmpty
        ? marcadores
        : Positioned.fill(
            child: Stack(
                children: [PolygonLayer(polygons: poligonos), marcadores]),
          );
    if (widget.opacidad >= 1) return capa;
    // `Opacity` sobre la capa entera y no color a color: los marcadores los
    // dibuja `lugar_marcadores.dart` con su propia paleta, y atenuar ahí sería
    // pasarle la opacidad a cada pieza del catálogo para que la olvide una.
    return Positioned.fill(
      child: Opacity(opacity: widget.opacidad, child: capa),
    );
  }
}

/// Salida cuando el catálogo no llegó: un texto pequeño que se puede tocar.
///
/// Deliberadamente **no** es un error: sin marcadores el mapa sigue sirviendo y
/// el pedido se puede atender igual, así que nada de icono de alerta, tarjeta ni
/// franja roja. Lo que arregla es el silencio — hasta ahora el motivo solo
/// quedaba en el log de depuración, invisible en release, y "a veces carga y a
/// veces no" no tenía por dónde empezar a mirarse.
class _AvisoReintento extends StatelessWidget {
  const _AvisoReintento({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Material(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Text(
                'No cargaron los sitios · Reintentar',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

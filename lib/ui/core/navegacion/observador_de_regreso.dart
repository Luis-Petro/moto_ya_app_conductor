import 'package:flutter/widgets.dart';

/// Avisa de que se cerró una pantalla que estaba **encima** del shell.
///
/// Existe por un hueco concreto: `TickerMode` —la señal con la que la franja de
/// avisos sabe que se volvió a su pestaña— solo cambia entre **ramas** del
/// shell, y las pantallas a pantalla completa (el alta, un pedido, el feedback)
/// se empujan en el navigator **raíz** con `parentNavigatorKey`. Mientras están
/// abiertas la rama del Inicio sigue activa, así que al cerrarlas no cambia nada
/// que la franja pueda observar por su cuenta y un aviso publicado entre medias
/// no se veía.
///
/// **No es `RouteObserver` + `RouteAware`, y no por gusto.** `RouteObserver`
/// avisa a quien se haya suscrito con la *ruta anterior*, y la ruta anterior a
/// una pantalla que se cierra es la del shell entero —la que vive en el navigator
/// raíz—, no la página de la pestaña donde vive la franja.
/// `ModalRoute.of(context)` desde dentro de la franja devuelve esa página de la
/// rama, así que la suscripción no se dispararía nunca. Con un contador que
/// cualquiera puede escuchar no hay que acertar con la ruta.
///
/// El contador es **estático** porque hay una sola pila de navegación por app,
/// igual que hay un solo `MapTileCache.store`. Quien escucha decide si le toca:
/// aquí no se sabe qué pestaña se está viendo.
class ObservadorDeRegreso extends NavigatorObserver {
  /// Sube una vez por pantalla cerrada. Nunca baja ni se reinicia: lo único que
  /// importa es que cambie.
  static final ValueNotifier<int> regresos = ValueNotifier<int>(0);

  /// Solo las pantallas. Un `PopupRoute` —diálogo, hoja, menú— no es un
  /// `PageRoute`, y cerrar un diálogo no es volver a ninguna parte: contarlo
  /// serían consultas de más cada vez que alguien confirma algo.
  void _anotar(Route<dynamic> route) {
    if (route is PageRoute) {
      regresos.value++;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _anotar(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _anotar(route);
}

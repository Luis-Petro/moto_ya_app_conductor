import 'dart:io';

import 'package:app_conductor/ui/core/widgets/lugar_marcadores.dart';
import 'package:flutter_test/flutter_test.dart';

/// El mapa del pedido en curso, mirado desde una moto.
///
/// `PedidoActivoScreen` necesita el service locator entero para montarse (y un
/// mapa, tiles y GPS), así que estas decisiones se vigilan sobre el código: son
/// justo las que al romperse **no dan ningún error** y solo se notan en la calle,
/// con el cliente esperando.
void main() {
  final franja = File(
    'lib/ui/features/pedido_activo/pedido_activo_screen.dart',
  ).readAsStringSync();
  final completo = File(
    'lib/ui/features/pedido_activo/mapa_pedido_screen.dart',
  ).readAsStringSync();

  group('La franja se mira, no se maneja', () {
    test('la interacción está apagada', () {
      // `initialCameraFit` se aplica una sola vez: con la interacción encendida,
      // un arrastre accidental —el dedo pasa por encima al desplazar la ficha—
      // dejaba la franja encuadrada en un descampado, sin forma de volver. Y
      // además le robaba el gesto a la lista de abajo.
      expect(franja, contains('flags: InteractiveFlag.none'));
    });

    test('toda la franja abre el mapa completo', () {
      // No un icono pequeño en una esquina: el objetivo táctil es la franja
      // entera, que es lo más forgiving para quien acaba de parar la moto.
      expect(franja, contains('InkWell(onTap: widget.onAmpliar)'));
      expect(franja, contains("label: 'Ampliar el mapa del pedido'"));
    });

    test('el toque se anuncia con una pastilla visible', () {
      // Un mapa que se toca sin nada que lo diga es una función que no existe.
      expect(franja, contains("'Ampliar el mapa'"));
      expect(franja, contains('_PastillaAmpliar'));
    });
  });

  group('La franja no envejece sola', () {
    test('se reencuadra por objetivo o por salirse de cuadro', () {
      // Y por nada más. La posición llega cada pocos segundos: reencuadrar en
      // cada latido haría saltar el mapa mientras se lee.
      expect(franja, contains('cambioObjetivo'));
      expect(franja, contains('visibleBounds.contains'));
    });

    test('el reencuadre va fuera del build', () {
      // `fitCamera` mueve la cámara y notifica; hacerlo en mitad de la
      // construcción del árbol es un setState durante el build.
      expect(franja, contains('addPostFrameCallback'));
    });

    test('no se toca la cámara antes del primer fotograma', () {
      // `MapController.camera` y `fitCamera` lanzan si el mapa no se ha pintado,
      // y aquí se llaman desde un callback de GPS que puede llegar antes.
      for (final fuente in [franja, completo]) {
        expect(fuente, contains('onMapReady: _alEstarListo'));
        expect(fuente, contains('!_listo'));
      }
    });
  });

  group('El mapa completo', () {
    test('dibuja los lugares con su nombre', () {
      // Es el motivo de la pantalla: en un municipio sin nomenclatura, "la
      // droguería La Fe" es la dirección. La franja los pinta sin nombre porque
      // en 150 px las etiquetas taparían la ruta; aquí hay sitio.
      expect(franja, contains('LugaresLayer(mostrarNombres: false)'));
      expect(completo, contains('const LugaresLayer(),'));
      expect(
        completo,
        isNot(contains('mostrarNombres: false')),
        reason: 'El mapa completo se abre justo para leer los nombres.',
      );
    });

    test('abre encuadrado en el tramo que se está conduciendo', () {
      // Encuadrar el viaje entero suena más completo y es peor: en un municipio
      // de dos kilómetros el ajuste cae por debajo de `zoomMinimoLugares` y la
      // pantalla se abre sin un solo lugar dibujado.
      expect(completo, contains('_tramoActual'));
      expect(completo, contains('initialZoom: 16'));
      expect(
        zoomMinimoLugares,
        lessThanOrEqualTo(16),
        reason: 'El zoom de apertura del mapa quedó por debajo del zoom al que '
            'empiezan a dibujarse los lugares: se abriría vacío.',
      );
    });

    test('se puede volver al encuadre con un toque, y con uno solo', () {
      // Quien paneó y se perdió no quiere elegir entre "centrar en mí" y "ver
      // todo el viaje": quiere volver a lo que estaba mirando. Un control, sin
      // decisión que tomar con la moto al ralentí, y del tamaño táctil mínimo
      // entero — se toca con guante.
      expect(completo, contains('_BotonCentrar'));
      expect(completo, contains('_volverAEncuadrar'));
      expect(completo, contains('AppSpacing.minTouchTarget'));
      // Lo lee el lector de pantalla: un icono de diana no dice nada por sí solo.
      expect(completo, contains("label: 'Volver a centrar el mapa en ti y en tu destino'"));
    });

    test('conserva el view model de la pantalla del pedido', () {
      // Con una copia de los datos, el mapa nacería congelado en el instante del
      // toque: el punto azul se quedaría donde el conductor estaba al abrirlo.
      // Y `.value` es lo que impide que cerrarlo deseche el view model —y con él
      // el reporte de GPS del pedido en curso—.
      expect(completo, contains('ChangeNotifierProvider<PedidoActivoViewModel>.value'));
    });

    test('acredita OpenStreetMap', () {
      // No es decorativo: lo exige la licencia ODbL, y los términos gratuitos de
      // quien sirve los tiles.
      expect(completo, contains('osmAttribution()'));
    });
  });
}

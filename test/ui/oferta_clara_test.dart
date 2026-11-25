import 'dart:io';

import 'package:app_conductor/ui/core/widgets/map_widgets.dart';
import 'package:app_conductor/ui/features/inicio/mapa_de_zonas.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// La oferta se decide en un minuto, en la calle y a veces con el casco puesto.
///
/// Tres preguntas tienen que contestarse sin buscar: **dónde recojo, a dónde lo
/// llevo y si tengo que poner plata**. `PedidoEntranteScreen` necesita el service
/// locator y un mapa para montarse, así que estas decisiones se vigilan sobre el
/// código: son las que al romperse no dan ningún error.
void main() {
  final oferta = File(
    'lib/ui/features/pedido_entrante/pedido_entrante_screen.dart',
  ).readAsStringSync();
  final inicio = File(
    'lib/ui/features/inicio/inicio_screen.dart',
  ).readAsStringSync();
  final mapaPedido = File(
    'lib/ui/features/pedido_activo/mapa_pedido_screen.dart',
  ).readAsStringSync();

  group('Dónde recojo y a dónde lo llevo', () {
    test('los dos puntos van numerados y con el pin del mapa', () {
      expect(oferta, contains("'1 · RECOGES EN'"));
      expect(oferta, contains("'1 · COMPRAS EN'"));
      expect(oferta, contains("'2 · LO LLEVAS A'"));
      // El mismo dibujo que el mapa: la tienda y la casa significan lo mismo
      // en la oferta, en el pedido en curso y en la app del cliente.
      expect(oferta, contains('ilustracion: marcadorRecogida'));
      expect(oferta, contains('ilustracion: marcadorEntrega'));
    });

    test('el sitio va en letra de leer, no en pie de foto', () {
      final punto = oferta.substring(
        oferta.indexOf('class _PuntoRuta'),
        oferta.indexOf('class _Conector'),
      );
      expect(punto, contains('style: AppText.subtitle'));
    });

    test('el recorrido se ve en un mapa que no se maneja', () {
      final mapa = oferta.substring(oferta.indexOf('class _MapaOferta'));
      expect(mapa, contains('InteractiveFlag.none'));
      expect(mapa, contains('osmAttribution()'));
      // Va al final: lo que decide la oferta cabe antes sin desplazar.
      expect(
        oferta.indexOf('_ProponerTarifa(vm: vm)'),
        lessThan(oferta.indexOf('_MapaOferta(pedido: pedido)')),
      );
    });
  });

  group('¿Tengo que poner plata?', () {
    test('se dice en grande cuando sí', () {
      final aviso = oferta.substring(
        oferta.indexOf('class _AvisoAdelanto'),
        oferta.indexOf('class _TarjetaRuta'),
      );
      expect(aviso, contains('de tu bolsillo'));
      expect(aviso, contains('AppText.subtitle'));
      expect(aviso, contains('El cliente te los devuelve al entregar.'));
      // El historial del cliente sigue junto al monto.
      expect(aviso, contains('historialDelCliente(pedido)'));
    });

    test('y también cuando no', () {
      // Sin ese renglón, que no haya que adelantar se tenía que deducir de que
      // faltara un aviso.
      expect(oferta, contains("'No tienes que poner plata'"));
    });
  });

  test('"Rechazar" no se parte en dos líneas', () {
    // En un teléfono de 411 dp se leía "Rechaza / r".
    expect(oferta, contains("Text('Rechazar', maxLines: 1, softWrap: false)"));
    expect(oferta, contains('BoxFit.scaleDown'));
  });

  group('El mapa no se acerca de más', () {
    test('el encuadre tiene techo de zoom', () {
      final fit = encuadreDePuntos(const [
        LatLng(9.35400, -75.95300),
        LatLng(9.35401, -75.95301),
      ]) as FitBounds;
      // Dos puntos a un metro daban zoom 19: media cuadra en pantalla.
      expect(fit.maxZoom, isNotNull);
      expect(fit.maxZoom, lessThanOrEqualTo(17));
    });

    test('el de demanda del Inicio muestra el pueblo, no una calle', () {
      expect(zoomMaximoZonas, lessThanOrEqualTo(15));
      final zonas = File(
        'lib/ui/features/inicio/mapa_de_zonas.dart',
      ).readAsStringSync();
      expect(
        'zoomMaximo: zoomMaximoZonas'.allMatches(zonas).length,
        2,
        reason: 'El techo va en el encuadre inicial y en el reencuadre.',
      );
    });
  });

  test('el punto que no toca ahora dice qué es, sin lavarse', () {
    // Iba translúcido y sin nombre: sobre los lugares del catálogo se perdía.
    expect(mapaPedido, contains("'Después'"));
    expect(mapaPedido, contains("'Ya recogido'"));
    expect(mapaPedido, contains('rotuloSuave'));
  });

  test('la tarjeta del Inicio dice qué sigue, no la categoría', () {
    expect(inicio, contains('_queSigue(p)'));
    expect(inicio, contains("'Llévalo al cliente'"));
  });
}

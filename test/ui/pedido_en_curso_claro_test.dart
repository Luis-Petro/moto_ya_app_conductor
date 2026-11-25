import 'dart:io';

import 'package:app_conductor/data/repositories/pedido_repository.dart';
import 'package:app_conductor/data/services/tracking_service.dart';
import 'package:app_conductor/domain/models/categoria_servicio.dart';
import 'package:app_conductor/domain/models/estado_pedido.dart';
import 'package:app_conductor/domain/models/pedido.dart';
import 'package:app_conductor/ui/features/pedido_activo/pedido_activo_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

class _Pedidos extends Mock implements PedidoRepository {}

class _Tracking extends Mock implements TrackingService {}

/// La pantalla del pedido en curso, para quien no está acostumbrado a las apps.
///
/// Tres cosas tienen que leerse sin pensar: **qué hago ahora**, **a dónde voy**
/// y **cuándo toco el botón**. Y el botón no puede quedar debajo de los botones
/// de navegación del sistema.
void main() {
  Pedido pedido(EstadoPedido estado, {bool compra = false}) => Pedido(
        id: 403,
        clienteId: 1,
        conductorId: 2,
        categoria: CategoriaServicio.mercado,
        descripcion: 'Un paquete',
        origen: const LatLng(9.35, -75.95),
        destino: const LatLng(9.36, -75.96),
        requiereCompra: compra,
        estado: estado,
      );

  PedidoActivoViewModel vmCon(EstadoPedido estado, {bool compra = false}) =>
      PedidoActivoViewModel(_Pedidos(), _Tracking(), 403)
        ..pedido = pedido(estado, compra: compra);

  group('El botón dice lo que el conductor acaba de hacer', () {
    test('nunca el nombre técnico del estado', () {
      for (final e in [
        EstadoPedido.aceptado,
        EstadoPedido.enCompra,
        EstadoPedido.enCamino,
      ]) {
        for (final compra in [true, false]) {
          final vm = vmCon(e, compra: compra);
          expect(vm.etiquetaAvance, isNot(startsWith('Marcar')),
              reason: '"Marcar: En camino" obligaba a traducir: ¿voy o ya fui?');
          expect(vm.cuandoAvanzar, isNotEmpty,
              reason: 'Cada paso dice cuándo tocar el botón.');
        }
      }
    });

    test('cada estado tiene su frase', () {
      expect(vmCon(EstadoPedido.aceptado).etiquetaAvance, 'Ya llegué a recoger');
      expect(vmCon(EstadoPedido.aceptado, compra: true).etiquetaAvance,
          'Ya llegué al negocio');
      expect(vmCon(EstadoPedido.enCompra).etiquetaAvance,
          'Ya lo tengo, voy a entregar');
      expect(vmCon(EstadoPedido.enCamino).etiquetaAvance,
          'Ya entregué el pedido');
    });

    test('el paso se cuenta de 1 a 3', () {
      expect(vmCon(EstadoPedido.aceptado).pasoActual, 1);
      expect(vmCon(EstadoPedido.enCompra).pasoActual, 2);
      expect(vmCon(EstadoPedido.enCamino).pasoActual, 3);
      expect(PedidoActivoViewModel.totalPasos, 3);
    });

    test('el objetivo pasa de la recogida a la entrega al salir en camino', () {
      final aRecoger = vmCon(EstadoPedido.enCompra);
      expect(aRecoger.vaARecogida, isTrue);
      expect(aRecoger.puntoObjetivo, aRecoger.pedido!.origen);
      final aEntregar = vmCon(EstadoPedido.enCamino);
      expect(aEntregar.vaARecogida, isFalse);
      expect(aEntregar.puntoObjetivo, aEntregar.pedido!.destino);
    });
  });

  group('Sobre el código de la pantalla', () {
    final pantalla = File(
      'lib/ui/features/pedido_activo/pedido_activo_screen.dart',
    ).readAsStringSync();
    final mapa = File(
      'lib/ui/features/pedido_activo/mapa_pedido_screen.dart',
    ).readAsStringSync();

    test('la barra de acción respeta los botones de navegación del sistema',
        () {
      // Con Android de borde a borde, ◁ ○ □ se pintaban encima de "Entregado".
      expect(pantalla, contains('bottomNavigationBar: _BarraAccion('));
      final barra = pantalla.substring(pantalla.indexOf('class _BarraAccion'));
      expect(barra, contains('SafeArea('));
      expect(barra, contains('top: false'));
    });

    test('un segundo toque nervioso no salta el paso siguiente', () {
      // El botón cambia de texto bajo el dedo: sin pausa, dos toques seguidos
      // avanzaban dos estados, y eso no se puede deshacer.
      expect(pantalla, contains('_enfriando'));
      expect(pantalla,
          contains('vm.proximoEstado == null || vm.procesando || _enfriando'));
    });

    test('qué es el pedido está siempre a la vista', () {
      expect(pantalla, contains('_QueEsElPedido(pedido: pedido)'));
      expect(pantalla, isNot(contains("'Ver todo el detalle'")));
    });

    test('los contactos llevan nombre, no solo un icono', () {
      expect(pantalla, contains("const Text('Llamar')"));
      expect(pantalla, contains("const Text('WhatsApp')"));
    });

    test('franja y mapa completo pintan los mismos marcadores', () {
      // Los mismos pines que la app cliente, y el objetivo actual rotulado.
      expect(pantalla, contains('marcadoresDelPedido('));
      expect(mapa, contains('marcadoresDelPedido('));
      expect(mapa, contains("'Recoge aquí'"));
      expect(mapa, contains("'Entrega aquí'"));
      expect(mapa, contains('marcadorConductor'));
    });
  });
}

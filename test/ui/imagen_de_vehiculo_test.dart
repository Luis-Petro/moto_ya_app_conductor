import 'dart:typed_data';

import 'package:app_conductor/data/services/banner_image_store.dart';
import 'package:app_conductor/di/locator.dart';
import 'package:app_conductor/domain/models/catalogo_vehiculos.dart';
import 'package:app_conductor/ui/core/widgets/imagen_de_vehiculo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las imágenes del catálogo de vehículos: cuáles se piden y qué se pinta
/// cuando no hay ninguna.
///
/// **Qué se pide es la mitad del test, y no es un detalle de rendimiento.** Al
/// abrir el paso del vehículo se piden las imágenes de las marcas del tipo
/// elegido, y eso lo descarga cada conductor que se registra, con datos móviles.
/// Pedir las de todo el catálogo sería la lección de la rejilla de aliados otra
/// vez: construir la rejilla completa *era* descargar la foto de cada producto
/// del municipio.
void main() {
  late _StoreFake store;

  setUp(() {
    store = _StoreFake();
    if (locator.isRegistered<BannerImageStore>()) {
      locator.unregister<BannerImageStore>();
    }
    locator.registerSingleton<BannerImageStore>(store);
  });

  tearDown(() => locator.unregister<BannerImageStore>());

  Widget montar(List<Widget> hijos) => MaterialApp(
        home: Scaffold(body: Column(children: hijos)),
      );

  testWidgets('una fila sin imagen no pide nada y pinta la silueta de su tipo',
      (tester) async {
    await tester.pumpWidget(montar([
      const ImagenDeVehiculo(url: null, icono: IconoVehiculo.bicicleta),
    ]));
    await tester.pump();

    expect(store.pedidas, isEmpty, reason: 'no hay nada que pedir');
    final icono = tester.widget<Icon>(find.byType(Icon));
    expect(icono.icon, IconoVehiculo.bicicleta.silueta);
  });

  testWidgets('la silueta es la del tipo y NUNCA la de otro nivel',
      (tester) async {
    // El logo de una marca no puede hacer de foto de sus seis modelos: saldrían
    // los seis con la misma imagen, que es exactamente lo que no distingue nada.
    await tester.pumpWidget(montar([
      const ImagenDeVehiculo(url: null, icono: IconoVehiculo.moto),
      const ImagenDeVehiculo(url: null, icono: IconoVehiculo.carro),
    ]));
    await tester.pump();

    final iconos =
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon).toList();
    expect(iconos, [IconoVehiculo.moto.silueta, IconoVehiculo.carro.silueta]);
  });

  testWidgets('con bytes se pinta la imagen, venga de la red o de la caché',
      (tester) async {
    // El store ya resuelve el 200 y el **304** de la caché en el mismo camino:
    // aquí lo que importa es que la condición para pintar sea «hay bytes».
    store.respuesta = _pngDeUnPixel;
    await tester.pumpWidget(montar([
      const ImagenDeVehiculo(url: 'https://cdn/boxer.webp', icono: IconoVehiculo.moto),
    ]));
    await tester.pumpAndSettle();

    expect(store.pedidas, ['https://cdn/boxer.webp']);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('una imagen que no llega deja la silueta, no un hueco gris',
      (tester) async {
    store.respuesta = null; // como un timeout o un teléfono sin cobertura
    await tester.pumpWidget(montar([
      const ImagenDeVehiculo(url: 'https://cdn/roto.webp', icono: IconoVehiculo.moto),
    ]));
    await tester.pumpAndSettle();

    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('se pide una imagen por fila y ni una más', (tester) async {
    // Diez marcas de un tipo son diez peticiones; los modelos de las marcas que
    // no se desplegaron no se construyen, así que no se piden nunca.
    store.respuesta = _pngDeUnPixel;
    await tester.pumpWidget(montar([
      const ImagenDeVehiculo(url: 'https://cdn/a.webp', icono: IconoVehiculo.moto),
      const ImagenDeVehiculo(url: 'https://cdn/b.webp', icono: IconoVehiculo.moto),
      const ImagenDeVehiculo(url: null, icono: IconoVehiculo.moto),
    ]));
    await tester.pumpAndSettle();

    expect(store.pedidas, ['https://cdn/a.webp', 'https://cdn/b.webp']);
  });

  testWidgets('la silueta ocupa el mismo espacio que ocuparía la imagen',
      (tester) async {
    // Sin eso la lista da un salto por cada foto que llega.
    await tester.pumpWidget(montar([
      const ImagenDeVehiculo(url: null, icono: IconoVehiculo.moto, tamano: 72),
    ]));
    await tester.pump();

    expect(tester.getSize(find.byType(ImagenDeVehiculo)), const Size(72, 72));
  });
}

/// PNG de 1×1 transparente: lo mínimo que `Image.memory` sabe decodificar.
final Uint8List _pngDeUnPixel = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

/// Store de mentira que apunta **qué** se pidió, que es el punto del test.
class _StoreFake extends Fake implements BannerImageStore {
  final List<String> pedidas = [];
  Uint8List? respuesta;

  @override
  Future<Uint8List?> bytes(String url) async {
    pedidas.add(url);
    return respuesta;
  }
}

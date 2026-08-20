import 'dart:convert';
import 'dart:typed_data';

import 'package:app_conductor/data/services/app_version_service.dart';
import 'package:app_conductor/data/services/banner_descartes.dart';
import 'package:app_conductor/data/services/banner_image_store.dart';
import 'package:app_conductor/data/services/banner_service.dart';
import 'package:app_conductor/di/locator.dart';
import 'package:app_conductor/domain/models/banner_app.dart';
import 'package:app_conductor/ui/core/navegacion/observador_de_regreso.dart';
import 'package:app_conductor/ui/core/widgets/banner_version.dart';
import 'package:app_conductor/ui/core/widgets/carrusel_banners.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockVersion extends Mock implements AppVersionService {}

class _MockBanners extends Mock implements BannerService {}

class _MockImagenes extends Mock implements BannerImageStore {}

class _MockDescartes extends Mock implements BannerDescartes {}

/// Un `PopupRoute` cualquiera —diálogo, hoja, menú—: lo que el observador **no**
/// debe contar. Se fabrica a mano para no necesitar un `BuildContext`.
class _RutaPopupFalsa extends PopupRoute<void> {
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      const SizedBox.shrink();
}

/// PNG de 1x1 válido: basta para que `Image.memory` tenga algo que decodificar.
final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

/// Otro PNG válido, con bytes distintos: es lo que permite comprobar que lo
/// pintado cambió de verdad y no solo que se volvió a pedir.
final Uint8List _otroPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAARnQU1BAACx'
    'jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAANSURBVBhXY/iUIvcfAAY0AnQymbOtAAAAAElF'
    'TkSuQmCC');

final DateTime _publicacion = DateTime.utc(2026, 8, 1, 10);

BannerApp _banner(
  int id, {
  bool descartable = true,
  String? enlace,
  DateTime? publicadoEn,
  String? imagenUrl,
  String? texto,
}) =>
    BannerApp(
      id: id,
      imagenUrl: imagenUrl ?? 'https://archivos.zumbeo.com/banners/$id.jpg',
      textoAlternativo: texto ?? 'Aviso $id',
      descartable: descartable,
      enlaceUrl: enlace,
      publicadoEn: publicadoEn ?? _publicacion,
    );

/// Los bytes que el carrusel tiene puestos ahora mismo en su única imagen.
///
/// Se lee del proveedor y no de la pantalla: el proveedor está en cuanto se
/// construye el widget, así que la comprobación no depende de cuándo termine de
/// decodificar la imagen.
Uint8List _bytesPintados(WidgetTester tester) =>
    (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes;

void main() {
  late _MockVersion version;
  late _MockBanners banners;
  late _MockImagenes imagenes;
  late _MockDescartes descartes;

  setUp(() {
    version = _MockVersion();
    banners = _MockBanners();
    imagenes = _MockImagenes();
    descartes = _MockDescartes();

    locator
      ..registerSingleton<AppVersionService>(version)
      ..registerSingleton<BannerService>(banners)
      ..registerSingleton<BannerImageStore>(imagenes)
      ..registerSingleton<BannerDescartes>(descartes);

    when(() => version.nuevaVersionDisponible()).thenAnswer((_) async => null);
    when(() => banners.vigentes()).thenAnswer((_) async => const <BannerApp>[]);
    when(() => descartes.descartados()).thenAnswer((_) async => <String>{});
    when(() => descartes.descartar(any(), idsVigentes: any(named: 'idsVigentes')))
        .thenAnswer((_) async {});
    when(() => imagenes.bytes(any())).thenAnswer((_) async => _png);
  });

  tearDown(() => locator.reset());

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Align(alignment: Alignment.topCenter, child: CarruselBanners())),
    ));
    // Una pasada por cada await de la carga (versión, banners, descartes, bytes).
    await tester.pump();
    await tester.pump();
  }

  /// Desmonta para que el temporizador de avance no quede pendiente.
  Future<void> desmontar(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  testWidgets('sin avisos no ocupa nada', (tester) async {
    await montar(tester);

    expect(find.byType(Image), findsNothing);
    expect(tester.getSize(find.byType(CarruselBanners)).height, 0);
  });

  testWidgets('el aviso de versión va primero', (tester) async {
    when(() => version.nuevaVersionDisponible()).thenAnswer(
        (_) async => const VersionVigente(version: '1.1.0', notas: 'Novedades'));
    when(() => banners.vigentes()).thenAnswer((_) async => [_banner(7)]);

    await montar(tester);

    // La primera página del carrusel es la tarjeta de versión; el banner queda
    // detrás. Es información de la propia app: no puede ir tras una promoción.
    expect(find.byType(TarjetaVersion), findsOneWidget);
    expect(find.text('Versión 1.1.0 disponible'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('descartar guarda el aviso Y su publicación', (tester) async {
    when(() => banners.vigentes()).thenAnswer((_) async => [_banner(7)]);

    await montar(tester);
    await tester.tap(find.byTooltip('Descartar'));
    await tester.pump();

    // La clave lleva el instante: con el id a secas, republicar el banner no lo
    // resucitaba en este teléfono.
    verify(() => descartes.descartar(
          '7:${_publicacion.millisecondsSinceEpoch}',
          idsVigentes: {7},
        )).called(1);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('un aviso no descartable no pinta la equis', (tester) async {
    when(() => banners.vigentes())
        .thenAnswer((_) async => [_banner(7, descartable: false)]);

    await montar(tester);

    expect(find.byType(Image), findsOneWidget);
    expect(find.byTooltip('Descartar'), findsNothing);
  });

  testWidgets('el banner que ya se descartó no vuelve', (tester) async {
    when(() => banners.vigentes()).thenAnswer((_) async => [_banner(7)]);
    when(() => descartes.descartados())
        .thenAnswer((_) async => {'7:${_publicacion.millisecondsSinceEpoch}'});

    await montar(tester);

    expect(find.byType(Image), findsNothing);
    expect(tester.getSize(find.byType(CarruselBanners)).height, 0);
  });

  testWidgets('republicar el banner lo vuelve a mostrar', (tester) async {
    // El usuario lo cerró cuando estaba publicado el 1 de agosto; el
    // administrador lo apagó y lo encendió, y ahora la publicación es otra.
    final republicado = _banner(7, publicadoEn: DateTime.utc(2026, 8, 20, 9));
    when(() => banners.vigentes()).thenAnswer((_) async => [republicado]);
    when(() => descartes.descartados())
        .thenAnswer((_) async => {'7:${_publicacion.millisecondsSinceEpoch}'});

    await montar(tester);

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('un aviso sin instante de publicación nunca se da por descartado',
      (tester) async {
    // Backend anterior al cambio: sin instante no se puede saber a qué
    // publicación se refería un descarte, y el error barato es mostrar de más.
    final b = BannerApp(
      id: 7,
      imagenUrl: 'https://archivos.zumbeo.com/banners/7.jpg',
      textoAlternativo: 'Aviso 7',
      descartable: true,
    );
    when(() => banners.vigentes()).thenAnswer((_) async => [b]);
    when(() => descartes.descartados()).thenAnswer((_) async => {'7:0'});

    await montar(tester);

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('una imagen que no baja se queda fuera del carrusel', (tester) async {
    when(() => banners.vigentes())
        .thenAnswer((_) async => [_banner(7), _banner(8)]);
    when(() => imagenes.bytes('https://archivos.zumbeo.com/banners/7.jpg'))
        .thenAnswer((_) async => null);

    await montar(tester);

    // Queda uno solo: sin indicadores, y sin contar el que no se ve.
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('con más de un aviso hay carrusel e indicadores', (tester) async {
    when(() => banners.vigentes())
        .thenAnswer((_) async => [_banner(7), _banner(8)]);

    await montar(tester);

    expect(find.byType(PageView), findsOneWidget);
    expect(find.bySemanticsLabel('Aviso 1 de 2'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('la altura sale del ancho y del ratio, no de la imagen', (tester) async {
    when(() => banners.vigentes()).thenAnswer((_) async => [_banner(7)]);

    await montar(tester);

    final ancho = tester.getSize(find.byType(CarruselBanners)).width;
    final alto = tester.getSize(find.byType(Image)).height;
    expect(alto, closeTo(ancho / kRatioBanner, 0.5));
  });

  // ─────────────────────────── refresco sin reiniciar ───────────────────────

  testWidgets('al volver del segundo plano aparece el banner recién publicado',
      (tester) async {
    await montar(tester);
    expect(find.byType(Image), findsNothing);

    when(() => banners.vigentes()).thenAnswer((_) async => [_banner(7)]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('volver a la pestaña recarga la franja', (tester) async {
    Widget arbol(bool visible) => MaterialApp(
          home: Scaffold(
            body: TickerMode(
              enabled: visible,
              child: const Align(
                alignment: Alignment.topCenter,
                child: CarruselBanners(),
              ),
            ),
          ),
        );

    await tester.pumpWidget(arbol(true));
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsNothing);

    // Se va a otra pestaña y, mientras, el administrador publica.
    await tester.pumpWidget(arbol(false));
    await tester.pump();
    when(() => banners.vigentes()).thenAnswer((_) async => [_banner(7)]);

    await tester.pumpWidget(arbol(true));
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('cerrar una pantalla de encima del shell recarga la franja',
      (tester) async {
    // `TickerMode` no cubre este caso: el alta, los pedidos y el feedback se
    // empujan en el navigator raíz, y mientras están abiertos la rama del Inicio
    // sigue activa. Sin esta señal, un aviso publicado mientras el conductor
    // atendía un pedido no aparecía al volver.
    await montar(tester);
    expect(find.byType(Image), findsNothing);

    when(() => banners.vigentes()).thenAnswer((_) async => [_banner(7)]);
    ObservadorDeRegreso.regresos.value++;
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });

  test('el observador cuenta las pantallas y no los diálogos', () {
    // Contar los `PopupRoute` sería una consulta de más cada vez que alguien
    // confirma algo en un diálogo, y esta app abre bastantes.
    final observador = ObservadorDeRegreso();

    final antesDelPopup = ObservadorDeRegreso.regresos.value;
    observador.didPop(_RutaPopupFalsa(), null);
    expect(ObservadorDeRegreso.regresos.value, antesDelPopup);

    final antesDeLaPagina = ObservadorDeRegreso.regresos.value;
    observador.didPop(
      MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
      null,
    );
    expect(ObservadorDeRegreso.regresos.value, antesDeLaPagina + 1);
  });

  testWidgets('reemplazar la imagen se repinta sin volver a publicar', (tester) async {
    // Editar no sella `publicadoEn` —una errata no es un aviso nuevo—, así que
    // la firma con la que el refresco decide si repintar no puede ser la clave
    // de descarte: con ella los bytes nuevos se bajaban y se tiraban, y la app
    // viva seguía enseñando la imagen anterior hasta que alguien matara el
    // proceso.
    const vieja = 'https://archivos.zumbeo.com/banners/7-v1.webp';
    const nueva = 'https://archivos.zumbeo.com/banners/7-v2.webp';
    when(() => banners.vigentes())
        .thenAnswer((_) async => [_banner(7, imagenUrl: vieja)]);
    when(() => imagenes.bytes(vieja)).thenAnswer((_) async => _png);
    when(() => imagenes.bytes(nueva)).thenAnswer((_) async => _otroPng);

    await montar(tester);
    expect(_bytesPintados(tester), _png);

    when(() => banners.vigentes())
        .thenAnswer((_) async => [_banner(7, imagenUrl: nueva)]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(_bytesPintados(tester), _otroPng);
  });

  testWidgets('corregir el texto alternativo se repinta', (tester) async {
    when(() => banners.vigentes())
        .thenAnswer((_) async => [_banner(7, texto: 'Farmacia abierta')]);

    await montar(tester);
    expect(tester.widget<Image>(find.byType(Image)).semanticLabel,
        'Farmacia abierta');

    when(() => banners.vigentes())
        .thenAnswer((_) async => [_banner(7, texto: 'Farmacia abierta hasta las 10')]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(tester.widget<Image>(find.byType(Image)).semanticLabel,
        'Farmacia abierta hasta las 10');
  });

  testWidgets('un refresco sin cambios no devuelve el carrusel a la primera tarjeta',
      (tester) async {
    when(() => banners.vigentes())
        .thenAnswer((_) async => [_banner(7), _banner(8)]);

    await montar(tester);
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Aviso 2 de 2'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('Aviso 2 de 2'), findsOneWidget,
        reason: 'mover la vista bajo quien está leyendo es peor que no refrescar');
    await desmontar(tester);
  });

  testWidgets('un refresco fallido deja en pantalla lo que ya se veía', (tester) async {
    when(() => banners.vigentes()).thenAnswer((_) async => [_banner(7)]);
    await montar(tester);
    expect(find.byType(Image), findsOneWidget);

    // `null` es "no se pudo preguntar", distinto de "no hay avisos".
    when(() => banners.vigentes()).thenAnswer((_) async => null);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('el aviso de versión cerrado no vuelve con el refresco', (tester) async {
    when(() => version.nuevaVersionDisponible()).thenAnswer(
        (_) async => const VersionVigente(version: '1.1.0', notas: 'Novedades'));

    await montar(tester);
    expect(find.byType(TarjetaVersion), findsOneWidget);
    await tester.tap(find.byTooltip('Descartar'));
    await tester.pump();
    expect(find.byType(TarjetaVersion), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.byType(TarjetaVersion), findsNothing,
        reason: 'su descarte es de sesión, y un refresco no es una sesión nueva');
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:app_conductor/data/services/app_version_service.dart';
import 'package:app_conductor/data/services/banner_descartes.dart';
import 'package:app_conductor/data/services/banner_image_store.dart';
import 'package:app_conductor/data/services/banner_service.dart';
import 'package:app_conductor/di/locator.dart';
import 'package:app_conductor/domain/models/banner_app.dart';
import 'package:app_conductor/ui/core/widgets/banner_version.dart';
import 'package:app_conductor/ui/core/widgets/carrusel_banners.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockVersion extends Mock implements AppVersionService {}

class _MockBanners extends Mock implements BannerService {}

class _MockImagenes extends Mock implements BannerImageStore {}

class _MockDescartes extends Mock implements BannerDescartes {}

/// PNG de 1x1 válido: basta para que `Image.memory` tenga algo que decodificar.
final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

final DateTime _publicacion = DateTime.utc(2026, 8, 1, 10);

BannerApp _banner(
  int id, {
  bool descartable = true,
  String? enlace,
  DateTime? publicadoEn,
}) =>
    BannerApp(
      id: id,
      imagenUrl: 'https://archivos.zumbeo.com/banners/$id.jpg',
      textoAlternativo: 'Aviso $id',
      descartable: descartable,
      enlaceUrl: enlace,
      publicadoEn: publicadoEn ?? _publicacion,
    );

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

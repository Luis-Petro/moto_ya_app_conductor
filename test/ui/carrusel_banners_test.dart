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

BannerApp _banner(int id, {bool descartable = true, String? enlace}) => BannerApp(
      id: id,
      imagenUrl: 'https://archivos.zumbeo.com/banners/$id.jpg',
      textoAlternativo: 'Aviso $id',
      descartable: descartable,
      enlaceUrl: enlace,
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
    when(() => descartes.descartados()).thenAnswer((_) async => <int>{});
    when(() => descartes.descartar(any())).thenAnswer((_) async {});
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

  testWidgets('descartar un banner guarda su id para siempre', (tester) async {
    when(() => banners.vigentes()).thenAnswer((_) async => [_banner(7)]);

    await montar(tester);
    await tester.tap(find.byTooltip('Descartar'));
    await tester.pump();

    verify(() => descartes.descartar(7)).called(1);
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
    when(() => descartes.descartados()).thenAnswer((_) async => {7});

    await montar(tester);

    expect(find.byType(Image), findsNothing);
    expect(tester.getSize(find.byType(CarruselBanners)).height, 0);
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
}

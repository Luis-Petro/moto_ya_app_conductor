import 'package:app_conductor/data/repositories/usuario_repository.dart';
import 'package:app_conductor/data/services/api_client.dart';
import 'package:app_conductor/data/services/api_result.dart';
import 'package:app_conductor/data/services/lugar_service.dart';
import 'package:app_conductor/di/locator.dart';
import 'package:app_conductor/domain/models/demanda_zonas.dart';
import 'package:app_conductor/ui/core/widgets/lugares_layer.dart';
import 'package:app_conductor/ui/core/widgets/skeleton.dart';
import 'package:app_conductor/ui/features/inicio/mapa_de_zonas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// El bloque "Dónde están pidiendo" del Inicio del conductor.
///
/// Las tres cosas que se vigilan aquí tienen en común que **al romperse no dan
/// ningún error**: compilan, no se ven en una revisión y no salen en una
/// captura. Solo se notan con el mapa delante y datos reales encima.
void main() {
  // El mapa lleva dentro la capa de lugares, que resuelve sus dependencias por
  // el service locator en cuanto se monta. Sin esto, cualquier test que pinte el
  // mapa de verdad revienta con un `StateError` de GetIt que no habla de mapas.
  setUp(() {
    locator
      ..registerSingleton<LugarService>(LugarService(_ApiVacia()))
      ..registerSingleton<UsuarioRepository>(_UsuariosFake());
  });

  tearDown(() => locator.reset());

  CeldaDemanda celda(double lat, double lng, [NivelDemanda n = NivelDemanda.alta]) =>
      CeldaDemanda(centro: LatLng(lat, lng), pedidos: 3, nivel: n);

  DemandaZonas demandaCon(List<CeldaDemanda> celdas) => DemandaZonas(
        periodoHoras: 24,
        totalPedidos: 11,
        actualizadoEn: DateTime(2026, 9, 6),
        celdas: celdas,
      );

  Widget arbol(
    Widget hijo, {
    Size pantalla = const Size(360, 780),
  }) =>
      MediaQuery(
        data: MediaQueryData(size: pantalla),
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: hijo))),
      );

  MapaDeZonas bloque({
    DemandaZonas? demanda,
    bool cargando = false,
    LatLng? ubicacion,
    LatLng? centroMunicipio,
  }) =>
      MapaDeZonas(
        demanda: demanda,
        cargando: cargando,
        ubicacion: ubicacion,
        centroMunicipio: centroMunicipio,
        onReintentar: () {},
      );

  group('El mapa no cambia de tamaño', () {
    testWidgets('los tres estados miden exactamente lo mismo', (tester) async {
      // El esqueleto, el aviso de datos insuficientes y el mapa comparten un
      // solo `SizedBox`. Si midieran distinto, la pantalla daría un salto justo
      // al llegar los datos — que es cuando el conductor está mirando.
      final altos = <double>[];

      for (final estado in [
        bloque(cargando: true),
        bloque(),
        bloque(demanda: demandaCon(const [])),
      ]) {
        await tester.pumpWidget(arbol(estado));
        await tester.pump();
        altos.add(tester.getSize(find.byType(MapaDeZonas)).height);
      }

      expect(altos.toSet(), hasLength(1),
          reason: 'los estados del bloque midieron distinto: $altos');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('mientras carga hay esqueleto, no un hueco', (tester) async {
      await tester.pumpWidget(arbol(bloque(cargando: true)));
      await tester.pump();

      expect(find.byType(Skeleton), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('el alto no depende de si hay avisos: nadie se lo puede pasar', () {
      // El parámetro `alturaMapa` decidía entre "todo lo que sobre de pantalla"
      // y 260 px según hubiera banners arriba, así que la llegada de una oferta
      // reorganizaba la pantalla entera con el encuadre moviéndose debajo del
      // dedo. Ya no existe, y esto es lo que impide que vuelva.
      expect(
        MapaDeZonas(
          demanda: null,
          cargando: false,
          ubicacion: null,
          centroMunicipio: null,
          onReintentar: () {},
        ),
        isA<MapaDeZonas>(),
      );
    });
  });

  group('El alto sale del ancho de la pantalla', () {
    testWidgets('crece con la pantalla, en vez de ser 260 px siempre',
        (tester) async {
      late double estrecha;
      late double ancha;

      await tester.pumpWidget(
        arbol(
          Builder(builder: (c) {
            estrecha = altoDelMapaDeZonas(c);
            return const SizedBox.shrink();
          }),
          pantalla: const Size(360, 780),
        ),
      );
      await tester.pumpWidget(
        arbol(
          Builder(builder: (c) {
            ancha = altoDelMapaDeZonas(c);
            return const SizedBox.shrink();
          }),
          pantalla: const Size(430, 930),
        ),
      );

      expect(ancha, greaterThan(estrecha));
    });

    testWidgets('nunca se come más de media pantalla', (tester) async {
      // El teléfono ancho y corto (o el modo horizontal): con `ancho × 1,1` el
      // mapa dejaría el bloque de ganancias fuera de la vista.
      late double alto;
      await tester.pumpWidget(
        arbol(
          Builder(builder: (c) {
            alto = altoDelMapaDeZonas(c);
            return const SizedBox.shrink();
          }),
          pantalla: const Size(800, 400),
        ),
      );

      expect(alto, lessThanOrEqualTo(400 * 0.55));
    });
  });

  group('El encabezado dice el periodo, no cuántos pedidos hubo', () {
    testWidgets('con datos se nombra la ventana y no el total', (tester) async {
      // El total es la cifra de negocio del municipio. Enseñársela a cada
      // conductor la convierte en una medida de lo que la plataforma mueve
      // —"once pedidos en todo el día"— justo en la pantalla desde la que
      // decide si vale la pena salir a trabajar.
      final d = demandaCon([celda(9.35, -75.95)]);
      await tester.pumpWidget(arbol(bloque(demanda: d)));
      await tester.pump();

      expect(find.text(d.periodoLabel), findsOneWidget);
      expect(find.textContaining('${d.totalPedidos} pedidos'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('El orden de las capas', () {
    test('los lugares van por encima de las manchas de demanda', () {
      // Los círculos son manchas translúcidas de cientos de metros: dibujados
      // encima tapaban el nombre de la droguería justo en las zonas con
      // pedidos, que son las únicas que hay que mirar. Es un fallo que compila,
      // no se ve en un diff y no aparece en una captura sin datos reales.
      final capas = capasDelMapaDeZonas(
        celdas: [celda(9.35, -75.95)],
        ubicacion: const LatLng(9.36, -75.94),
      );

      final demanda = capas.indexWhere((c) => c is CircleLayer);
      final lugares = capas.indexWhere((c) => c is LugaresLayer);
      final conductor = capas.indexWhere((c) => c is MarkerLayer);

      expect(demanda, greaterThan(-1));
      expect(lugares, greaterThan(demanda),
          reason: 'la mancha de demanda vuelve a tapar los sitios');
      expect(conductor, greaterThan(lugares),
          reason: 'dónde estoy yo es lo último que puede taparse');
    });

    test('sin ubicación no se pinta el marcador del conductor', () {
      final capas = capasDelMapaDeZonas(
        celdas: [celda(9.35, -75.95)],
        ubicacion: null,
      );

      expect(capas.whereType<MarkerLayer>(), isEmpty);
    });

    test('la capa de lugares recarga al reaparecer', () {
      // Este mapa vive en el shell y no se desmonta nunca: sin esto, su
      // `initState` es el único intento de toda la sesión y cae siempre en el
      // arranque en frío.
      final lugares = capasDelMapaDeZonas(
        celdas: const [],
        ubicacion: null,
      ).whereType<LugaresLayer>().single;

      expect(lugares.recargarAlReaparecer, isTrue);
    });
  });

  group('La cámara', () {
    testWidgets('el gesto la suelta y ofrece volver a centrar', (tester) async {
      await tester.pumpWidget(
        arbol(bloque(demanda: demandaCon([celda(9.35, -75.95)]))),
      );
      await tester.pump();
      expect(find.byType(BotonRecentrar), findsNothing);

      await tester.drag(find.byType(FlutterMap), const Offset(-60, 0));
      await tester.pump();

      expect(find.byType(BotonRecentrar), findsOneWidget);

      // Y el botón la retoma antes de que venza la espera.
      await tester.tap(find.byType(BotonRecentrar));
      await tester.pump();
      expect(find.byType(BotonRecentrar), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('la espera tras el gesto no sobrevive al desmontaje',
        (tester) async {
      // Un `Timer` pendiente hace fallar cualquier test que lo dispare, y en la
      // app vuelve sobre un `State` que ya no existe.
      await tester.pumpWidget(
        arbol(bloque(demanda: demandaCon([celda(9.35, -75.95)]))),
      );
      await tester.pump();
      await tester.drag(find.byType(FlutterMap), const Offset(-60, 0));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(esperaTrasElGesto + const Duration(seconds: 1));
      // Sin el `cancel` en `dispose`, el `pump` de arriba revienta aquí.
    });

    testWidgets('la demanda que llega tarde reencuadra el mapa',
        (tester) async {
      // El caso normal: la consulta de demanda es la más lenta del Inicio, así
      // que el mapa se dibuja antes con la lista vacía. Encuadrar solo en
      // `initialCameraFit` dejaba los círculos fuera de la pantalla.
      await tester.pumpWidget(arbol(bloque(cargando: true)));
      await tester.pump();

      final lejos = [celda(9.50, -75.80), celda(9.52, -75.78)];
      await tester.pumpWidget(arbol(bloque(demanda: demandaCon(lejos))));
      await tester.pump();
      await tester.pump();

      final camara = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options;
      expect(camara.initialCameraFit, isNotNull);
      // El encuadre efectivo lo aplica el controlador tras el fotograma; lo que
      // se comprueba es que las dos celdas caben en lo que se está viendo.
      final visible = MapCamera.of(
        tester.element(find.byType(CircleLayer)),
      ).visibleBounds;
      for (final c in lejos) {
        expect(visible.contains(c.centro), isTrue,
            reason: 'la celda ${c.centro} quedó fuera del encuadre');
      }

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

/// El catálogo de lugares no es lo que se prueba aquí: responde vacío y calla.
class _ApiVacia extends Fake implements ApiClient {
  @override
  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic data)? parse,
  }) async =>
      Ok<T>(parse!(const []));
}

class _UsuariosFake extends Fake implements UsuarioRepository {
  @override
  Future<int?> resolverMunicipio(
          {Duration presupuesto = const Duration(seconds: 20)}) async =>
      1;
}

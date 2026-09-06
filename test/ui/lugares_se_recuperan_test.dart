import 'package:app_conductor/data/repositories/usuario_repository.dart';
import 'package:app_conductor/data/services/api_client.dart';
import 'package:app_conductor/data/services/api_result.dart';
import 'package:app_conductor/data/services/lugar_service.dart';
import 'package:app_conductor/di/locator.dart';
import 'package:app_conductor/ui/core/navegacion/observador_de_regreso.dart';
import 'package:app_conductor/ui/core/widgets/lugares_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Que un tropiezo al cargar los lugares **no dure toda la sesión**.
///
/// El mapa del Inicio vive en el `StatefulShellRoute.indexedStack` y no se
/// desmonta nunca: su `initState` era el único intento de toda la sesión, y cae
/// siempre en el arranque en frío de la app, compitiendo con el perfil, los
/// municipios, los pedidos, los banners y la precarga de tiles. Si ese intento
/// salía mal, el mapa se quedaba sin marcadores hasta que alguien matara la app,
/// mientras los demás mapas se recuperaban solos porque cada apertura los
/// remonta.
///
/// Lo que se vigila aquí es esa recuperación **y su precio**: que no se convierta
/// en una petición por cada vez que alguien cambia de pestaña.
void main() {
  const municipio = 1;

  /// Una fila del catálogo tal y como la manda el backend.
  Map<String, dynamic> fila(int id, String nombre) => {
        'id': id,
        'nombre': nombre,
        'categoria': 'FARMACIA',
        'lat': 9.35,
        'lng': -75.95,
      };

  late _ApiFake api;

  setUp(() {
    api = _ApiFake([fila(1, 'Droguería La Fe')]);
    locator
      ..registerSingleton<LugarService>(LugarService(api))
      ..registerSingleton<UsuarioRepository>(_UsuariosFake());
  });

  tearDown(() => locator.reset());

  /// Monta la capa dentro de un mapa. [visible] simula la rama del shell:
  /// `TickerMode` es lo que `go_router` apaga en las pestañas que no se ven.
  Widget arbol({required bool visible, bool recarga = true}) => MaterialApp(
        home: Scaffold(
          body: TickerMode(
            enabled: visible,
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(9.35, -75.95),
                initialZoom: 16,
              ),
              children: [
                LugaresLayer(
                  municipioId: municipio,
                  recargarAlReaparecer: recarga,
                ),
              ],
            ),
          ),
        ),
      );

  /// Una pasada por cada `await` de la carga, más la del `setState`.
  Future<void> asentar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  group('El mapa se recupera al reaparecer', () {
    testWidgets('un fallo y volver a la pestaña trae los marcadores',
        (tester) async {
      api.falla = true;
      await tester.pumpWidget(arbol(visible: true));
      await asentar(tester);
      expect(find.byIcon(Icons.local_pharmacy), findsNothing);

      // Se va a otra pestaña y vuelve. Esta vez la red responde.
      await tester.pumpWidget(arbol(visible: false));
      await tester.pump();
      api.falla = false;
      await tester.pumpWidget(arbol(visible: true));
      await asentar(tester);

      expect(find.byIcon(Icons.local_pharmacy), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('al volver del segundo plano vuelve a pedir', (tester) async {
      api.falla = true;
      await tester.pumpWidget(arbol(visible: true));
      await asentar(tester);
      expect(find.byIcon(Icons.local_pharmacy), findsNothing);

      api.falla = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await asentar(tester);

      expect(find.byIcon(Icons.local_pharmacy), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('al cerrarse una pantalla de encima vuelve a pedir',
        (tester) async {
      // `TickerMode` no se entera de esto: los flujos a pantalla completa van
      // con `parentNavigatorKey: rootKey` y la rama del Inicio nunca deja de
      // estar activa mientras están abiertos. De ahí el observador aparte.
      api.falla = true;
      await tester.pumpWidget(arbol(visible: true));
      await asentar(tester);
      expect(find.byIcon(Icons.local_pharmacy), findsNothing);

      api.falla = false;
      ObservadorDeRegreso.regresos.value++;
      await asentar(tester);

      expect(find.byIcon(Icons.local_pharmacy), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('con el catálogo en caché, reaparecer no cuesta una petición',
        (tester) async {
      // Es la propiedad que hace aceptable disparar la recarga por tres hechos
      // distintos, y la primera que se pierde en cuanto alguien "fuerza" la
      // recarga por si acaso.
      await tester.pumpWidget(arbol(visible: true));
      await asentar(tester);
      expect(find.byIcon(Icons.local_pharmacy), findsOneWidget);
      expect(api.llamadas, 1);

      await tester.pumpWidget(arbol(visible: false));
      await tester.pump();
      await tester.pumpWidget(arbol(visible: true));
      await asentar(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await asentar(tester);
      ObservadorDeRegreso.regresos.value++;
      await asentar(tester);

      expect(api.llamadas, 1, reason: 'la caché vigente tiene que resolverlo');
      expect(find.byIcon(Icons.local_pharmacy), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('con la recarga apagada, ninguna señal dispara nada',
        (tester) async {
      // Los demás mapas son rutas empujadas que se remontan al abrirse:
      // encenderles esto serían recargas que nadie pidió.
      api.falla = true;
      await tester.pumpWidget(arbol(visible: true, recarga: false));
      await asentar(tester);
      final trasElMontaje = api.llamadas;

      await tester.pumpWidget(arbol(visible: false, recarga: false));
      await tester.pump();
      await tester.pumpWidget(arbol(visible: true, recarga: false));
      await asentar(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await asentar(tester);
      ObservadorDeRegreso.regresos.value++;
      await asentar(tester);

      expect(api.llamadas, trasElMontaje);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('un catálogo vacío no ofrece reintentar', (tester) async {
      // "No hay lugares" es una respuesta correcta del servidor. Ofrecer
      // "Reintentar" ahí manda al conductor a repetir una consulta que salió
      // bien.
      api.datos = const [];
      await tester.pumpWidget(arbol(visible: true));
      await asentar(tester);

      expect(find.byIcon(Icons.local_pharmacy), findsNothing);
      expect(find.textContaining('Reintentar'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

/// `ApiClient` de mentira: cuenta las peticiones y puede fallar. Lo que tiene
/// que ver con plazos vive en `test/data/catalogo_de_lugares_test.dart`, sin
/// binding de widgets de por medio.
class _ApiFake extends Fake implements ApiClient {
  _ApiFake(this.datos);

  List<Map<String, dynamic>> datos;

  /// Devuelve un error, como una red que se cae.
  bool falla = false;

  int llamadas = 0;

  @override
  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic data)? parse,
  }) async {
    llamadas++;
    if (falla) {
      return const Err(Failure('sin conexión', kind: FailureKind.network));
    }
    return Ok<T>(parse!(datos));
  }
}

class _UsuariosFake extends Fake implements UsuarioRepository {
  @override
  Future<int?> resolverMunicipio(
          {Duration presupuesto = const Duration(seconds: 20)}) async =>
      1;
}

import 'dart:io';
import 'dart:math' as math;

import 'package:app_conductor/ui/core/theme/app_colors.dart';
import 'package:app_conductor/ui/core/widgets/brand.dart';
import 'package:app_conductor/ui/core/widgets/map_widgets.dart';
import 'package:app_conductor/ui/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// La carga del Inicio tiene que **verse**.
///
/// El reporte fue "recién entro al home queda en blanco un rato, no siempre".
/// El esqueleto sí se estaba pintando: era invisible. `AppColors.line` (#E3E8EE)
/// sobre `background` (#F7F8FA) con la opacidad animando desde 0.4 daba **1,06:1**
/// de contraste en el punto apagado y 1,15:1 a opacidad plena. Y el "no siempre"
/// lo explica `cargar()`, que solo fuerza la red cuando el perfil de conductor no
/// está en caché: con la caché cebada por el splash el esqueleto dura un frame.
///
/// Estos tests fijan las tres cosas que no se pueden aflojar sin volver al mismo
/// síntoma: el contraste, que el esqueleto lleve identidad real, y que el
/// encuadre del mapa no lance con la lista de puntos vacía.
void main() {
  group('Contraste del esqueleto', () {
    // WCAG 2.x, luminancia relativa. Se calcula aquí y no se copia un número:
    // el punto es medir el color de verdad que usa el widget.
    double canalLineal(double c) =>
        c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;

    double luminancia(Color c) =>
        0.2126 * canalLineal(c.r) + 0.7152 * canalLineal(c.g) + 0.0722 * canalLineal(c.b);

    double contraste(Color a, Color b) {
      final la = luminancia(a);
      final lb = luminancia(b);
      final claro = math.max(la, lb);
      final oscuro = math.min(la, lb);
      return (claro + 0.05) / (oscuro + 0.05);
    }

    /// Color que se ve realmente: el relleno pintado con su opacidad sobre el
    /// fondo. Es lo que el ojo compara, no el relleno a solas.
    Color compuesto(Color frente, Color fondo, double opacidad) => Color.from(
      alpha: 1,
      red: opacidad * frente.r + (1 - opacidad) * fondo.r,
      green: opacidad * frente.g + (1 - opacidad) * fondo.g,
      blue: opacidad * frente.b + (1 - opacidad) * fondo.b,
    );

    /// Suelo del requisito. No sale de WCAG —que no cubre elementos
    /// decorativos—: es el punto por debajo del cual, medido en un celular al
    /// sol, el bloque deja de leerse como "esto va a llegar" y pasa a leerse
    /// como "aquí no hay nada".
    const suelo = 1.4;

    test('en su punto más apagado se distingue del fondo de la pantalla', () {
      final ratio = contraste(
        compuesto(
          Skeleton.relleno,
          AppColors.background,
          Skeleton.opacidadMinima,
        ),
        AppColors.background,
      );

      expect(
        ratio,
        greaterThanOrEqualTo(suelo),
        reason:
            'El esqueleto queda en ${ratio.toStringAsFixed(2)}:1 contra el '
            'fondo. Por debajo de $suelo:1 es una pantalla en blanco con un '
            'AnimationController corriendo. Oscurece AppColors.skeleton o sube '
            'Skeleton.opacidadMinima.',
      );
    });

    test('también dentro de una tarjeta blanca', () {
      // Los bloques del esqueleto de Inicio se pintan sobre `background`, pero
      // el mismo widget se usa dentro de tarjetas: ahí el fondo es más claro y
      // el contraste no puede caer por debajo del suelo.
      final ratio = contraste(
        compuesto(Skeleton.relleno, AppColors.surface, Skeleton.opacidadMinima),
        AppColors.surface,
      );

      expect(ratio, greaterThanOrEqualTo(suelo));
    });

    test('los grises que fallaban siguen fallando la medición', () {
      // Guarda del guarda: si la fórmula se rompiera y devolviera siempre algo
      // grande, este test lo delata.
      final line = contraste(
        compuesto(AppColors.line, AppColors.background, 0.4),
        AppColors.background,
      );
      final placeholder = contraste(
        AppColors.mapPlaceholder,
        AppColors.background,
      );

      expect(line, lessThan(1.1));
      expect(placeholder, lessThan(suelo));
    });
  });

  group('Esqueleto del Inicio', () {
    testWidgets('sin identidad en sesión son bloques grises', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SkeletonInicio())),
      );

      expect(find.byType(InitialsAvatar), findsNothing);
      // Y sobre todo: no se inventa un nombre para tapar el hueco.
      expect(find.text('Conductor'), findsNothing);
      expect(find.byType(Skeleton), findsWidgets);
    });

    testWidgets('con identidad en sesión pinta el avatar y el nombre', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonInicio(nombre: 'Jhon', iniciales: 'JP'),
          ),
        ),
      );

      expect(find.byType(InitialsAvatar), findsOneWidget);
      expect(find.text('Jhon'), findsOneWidget);
      expect(find.text('JP'), findsOneWidget);
    });
  });

  group('Encuadre del mapa de demanda', () {
    test('sin ningún punto no lanza: cae al centro del municipio', () {
      // Este era el crash. `LatLngBounds.fromPoints([])` lanza, y la lista queda
      // vacía justo cuando no hay celdas de demanda y la ubicación aún no se ha
      // resuelto. En release eso se veía como un rectángulo gris sin texto.
      expect(() => encuadreDePuntos(const []), returnsNormally);
      expect(encuadreDePuntos(const []), isA<CameraFit>());
    });

    test('con puntos encuadra sobre ellos', () {
      final fit = encuadreDePuntos(const [
        LatLng(9.35, -75.95),
        LatLng(9.36, -75.94),
      ]);

      expect(fit, isA<FitBounds>());
    });
  });

  group('El Inicio distingue cargar de estar vacío', () {
    // `_ZonasDemanda` y `_InicioView` son privados y montarlos exige el service
    // locator entero, así que estas decisiones se vigilan sobre el código: son
    // exactamente las que al romperse no dan ningún error y dejan la pantalla
    // en blanco otra vez.
    final inicio = File(
      'lib/ui/features/inicio/inicio_screen.dart',
    ).readAsStringSync();

    test(
      'el área del mapa tiene rama propia mientras la demanda está en vuelo',
      () {
        // Sin esta rama, `demanda == null` con la consulta en vuelo no caía en
        // ninguna de las tres siguientes y dejaba medio alto de pantalla vacío.
        expect(inicio, contains('if (d == null && vm.cargandoDemanda)'));
        // Y va **antes** que la rama de error: si no, `demanda == null` mientras
        // carga se contaría como "no pudimos cargar las zonas".
        expect(
          inicio.indexOf('if (d == null && vm.cargandoDemanda)'),
          lessThan(inicio.indexOf('else if (d == null)')),
        );
      },
    );

    test('los cuatro desenlaces del área del mapa siguen siendo distintos', () {
      expect(inicio, contains("'No pudimos cargar las zonas de demanda.'"));
      expect(inicio, contains('Todavía no hay ningún pedido registrado'));
      expect(inicio, contains('_conAltoDeMapa(_mapa(d))'));
    });

    test('el mapa se construye solo en su rama', () {
      // La versión anterior calculaba el mapa en una variable al principio del
      // build y lo descartaba en dos de las tres ramas — construyendo el
      // encuadre que lanzaba.
      expect(inicio, contains('Widget _mapa(DemandaZonas d)'));
      expect(inicio, isNot(contains('final mapa = d == null')));
      // Y nadie llama a fromPoints por su cuenta: pasa por el helper con guarda.
      expect(inicio, isNot(contains('LatLngBounds.fromPoints(')));
      expect(inicio, contains('encuadreDePuntos('));
    });

    test('el esqueleto de carga recibe la identidad de la sesión', () {
      expect(inicio, contains('nombre: vm.nombre'));
      expect(inicio, contains('iniciales: vm.iniciales'));
      expect(inicio, contains('fotoUrl: vm.fotoUrl'));
    });

    test('la identidad se siembra antes del primer frame', () {
      final vm = File(
        'lib/ui/features/inicio/inicio_view_model.dart',
      ).readAsStringSync();
      final cargar = vm.substring(
        vm.indexOf('Future<void> cargar()'),
        vm.indexOf('_iniciarPoll();'),
      );
      // Antes del primer notifyListeners, o el esqueleto no la tiene.
      expect(
        cargar.indexOf('_sembrarIdentidadDeCache()'),
        lessThan(cargar.indexOf('notifyListeners()')),
      );
      expect(vm, contains('_usuarios.enCache'));
    });
  });

  test(
    'la app no deja que un fallo de build se vea como una pantalla vacía',
    () {
      // En release el `ErrorWidget` por defecto pinta un rectángulo gris **sin
      // texto**: idéntico a una pantalla en blanco. Con eso, "se rompió" y "está
      // cargando" son el mismo síntoma y no hay nada que diagnosticar.
      final main = File('lib/main.dart').readAsStringSync();

      expect(main, contains('ErrorWidget.builder ='));
      expect(main, contains('Algo falló en esta pantalla'));
      // El mensaje técnico solo en debug.
      expect(main, contains('kDebugMode'));
    },
  );
}

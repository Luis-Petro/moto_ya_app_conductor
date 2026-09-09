import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El paso del vehículo, ahora que el catálogo lo administra el panel.
///
/// La pantalla necesita el service locator entero para montarse, así que —igual
/// que `alta_por_pasos_test.dart`— estas reglas se vigilan sobre el código. Son
/// las que se rompen **sin ruido**: nada falla, nada se ve en una captura, y el
/// resultado es un conductor que no puede registrarse o un catálogo entero de
/// fotos bajándose en un teléfono con datos móviles.
void main() {
  final alta = File('lib/ui/features/alta_conductor/alta_conductor_screen.dart')
      .readAsStringSync();
  final vm =
      File('lib/ui/features/alta_conductor/alta_conductor_view_model.dart')
          .readAsStringSync();

  /// El cuerpo del paso del vehículo, sin el resto de la pantalla.
  final paso = alta.substring(
    alta.indexOf('class _PasoMoto'),
    alta.indexOf('class _PasoIdentidad'),
  );

  group('los tres desplegables salen del catálogo del servidor', () {
    test('la lista ya no viaja compilada dentro de la app', () {
      // Era el motivo entero del cambio: añadir una marca eran dos APK y
      // esperar a que la gente actualice.
      expect(File('lib/domain/models/catalogo_motos.dart').existsSync(), isFalse);
      expect(alta, isNot(contains('catalogo_motos')));
      expect(alta, isNot(contains('marcasMoto')));
      expect(alta, isNot(contains('modelosDe(')));
    });

    test('los tres niveles se leen del árbol y no de una lista fija', () {
      expect(paso, contains('vm.catalogo?.tipos'));
      expect(paso, contains('tipo?.marcas'));
      expect(paso, contains('marcaElegida?.modelos'));
    });

    test('los modelos que se construyen son los de la marca elegida', () {
      // Es lo que impide pedir las fotos de los modelos de las demás marcas: si
      // no se construyen, no se piden. La lección de la rejilla de aliados.
      expect(paso, contains('final modelos = marcaElegida?.modelos'));
      expect(paso, isNot(contains('for (final m in vm.catalogo')));
    });
  });

  group('«Otro» sigue existiendo en los tres niveles', () {
    test('los tres desplegables llevan su salida', () {
      // Una lista cerrada dejaría fuera al conductor con un vehículo poco
      // común, y el administrador que tendría que cargar la fila no está
      // delante.
      final salidas = RegExp('value: _AltaViewState._kOtro')
          .allMatches(paso)
          .length;
      expect(salidas, 3, reason: 'tipo, marca y modelo');
    });

    test('elegir «Otra» pasa a texto libre los niveles que dependen', () {
      // Si la marca no está en el catálogo, sus modelos tampoco pueden estarlo.
      final libres = alta.substring(
        alta.indexOf('bool get _marcaEsLibre'),
        alta.indexOf('bool _soloTextoLibre('),
      );
      expect(libres, contains('_tipoId == _kOtro || _marcaId == _kOtro'));
      expect(libres, contains('_marcaEsLibre || _modeloId == _kOtro'));
    });
  });

  group('un catálogo que no llegó no bloquea el alta', () {
    test('el paso cae a texto libre', () {
      // No es un respaldo de cortesía: al otro lado hay una persona que quiere
      // empezar a trabajar hoy, y un bache de red no puede costarle el día.
      expect(paso, contains('if (soloTextoLibre)'));
      expect(paso, contains('_camposLibres(context)'));
      expect(alta, contains('bool _soloTextoLibre(AltaConductorViewModel vm) => !vm.hayCatalogo'));
    });

    test('lo dice y ofrece reintentar', () {
      expect(paso, contains('No pudimos cargar la lista de vehículos'));
      expect(paso, contains('onPressed: onReintentarCatalogo'));
    });

    test('solo ofrece reintentar cuando la consulta FALLÓ', () {
      // Reintentar un catálogo que el servidor dice que está vacío no arregla
      // nada, y un botón que no arregla nada se pulsa una vez y se desconfía.
      expect(paso, contains('if (vm.catalogoFallo && !vm.cargandoCatalogo)'));
    });

    test('el catálogo se pide sin esperarlo y su fallo no toca el alta', () {
      // El paso del vehículo es el segundo, así que suele haber llegado; y si
      // no, cae a texto libre.
      expect(vm, contains('cargarCatalogo();'));
      expect(vm, contains('catalogoFallo = !res.isSuccess'));
    });
  });

  group('lo que se manda al servidor', () {
    test('con referencia va la referencia y NO el texto', () {
      // El texto lo compone el servidor: dos fuentes para lo mismo divergen, y
      // esta app componía «$marca $modelo» en el teléfono.
      final libre = alta.substring(
        alta.indexOf('String? get _vehiculoLibre'),
        alta.indexOf('String? get _vehiculoParaVer'),
      );
      expect(libre, contains('if (_modeloVehiculoId != null)'));
      expect(libre, contains('return null;'));
    });

    test('el texto que se ve en la revisión no es el que se guarda', () {
      // Componerlo aquí es presentación; lo que se persiste lo compone el
      // servidor a partir del catálogo.
      expect(alta, contains('vehiculo: _vehiculoParaVer'));
    });

    test('los dos campos se omiten cuando no aplican', () {
      // Mandar `null` explícito y no mandar nada son cosas distintas del otro
      // lado.
      final service =
          File('lib/data/services/conductor_service.dart').readAsStringSync();
      expect(service, contains("if (vehiculo != null) 'vehiculo': vehiculo"));
      expect(service,
          contains("if (modeloVehiculoId != null) 'modeloVehiculoId': modeloVehiculoId"));
    });
  });

  group('añadir un nivel no añade un paso', () {
    test('el alta sigue en tres pasos', () {
      // Los tres niveles son la misma pregunta —«cuál es tu vehículo»— y
      // partirla dejaría la placa y sus dos documentos separados del dato que
      // documentan.
      expect(alta, contains('_pasos = 3'));
    });

    test('la placa y las dos fotos del vehículo siguen en este paso', () {
      expect(paso, contains("_Label('Placa')"));
      expect(paso, contains('Tarjeta de propiedad'));
      expect(paso, contains('Foto de tu vehículo'));
    });
  });
}

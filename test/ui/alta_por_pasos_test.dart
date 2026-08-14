import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reglas del alta por pasos.
///
/// La pantalla necesita el service locator entero para montarse, así que se
/// vigilan sobre el código las tres decisiones que se rompen sin ruido: que no
/// se pueda avanzar con el paso incompleto, que atrás retroceda de paso en vez
/// de tirar el alta entera, y que el `vehiculo` siga viajando compuesto.
void main() {
  final alta = File('lib/ui/features/alta_conductor/alta_conductor_screen.dart')
      .readAsStringSync();

  group('Alta por pasos', () {
    test('son tres pasos', () {
      expect(alta, contains('_pasos = 3'));
    });

    test('continuar se bloquea con el paso incompleto', () {
      expect(alta, contains('habilitado: _pasoValido(vm)'));
      // Y cada paso tiene su propia condición: la del primero no puede exigir
      // la placa, que todavía no ha llegado.
      final valido = alta.substring(
        alta.indexOf('bool _pasoValido('),
        alta.indexOf('void _siguiente()'),
      );
      expect(valido, contains('0 => vm.tieneCedula'));
      expect(valido, contains('1 => _motoLista'));
    });

    test('los pasos se agrupan por lo que documentan', () {
      // Identidad (cédula + selfie) y moto (datos + tarjeta + foto). Antes las
      // cuatro fotos iban juntas y la tarjeta de propiedad quedaba a dos pasos
      // de la placa que aparece en ella.
      expect(alta, contains('_PasoIdentidad'));
      expect(alta, isNot(contains('class _PasoDocumentos')));

      // En el archivo `_PasoMoto` va antes que `_PasoIdentidad`; el orden de
      // los pasos lo fija el `PageView`, no el orden de las clases.
      final identidad = alta.substring(
        alta.indexOf('class _PasoIdentidad'),
        alta.indexOf('class _PasoRevision'),
      );
      expect(identidad, contains('Foto de tu cédula'));
      expect(identidad, contains('Selfie tuya'));
      expect(identidad, isNot(contains('Foto de tu moto')));

      final moto = alta.substring(
        alta.indexOf('class _PasoMoto'),
        alta.indexOf('class _PasoIdentidad'),
      );
      expect(moto, contains('Tarjeta de propiedad'));
      expect(moto, contains('Foto de tu moto'));
      expect(moto, isNot(contains('Foto de tu cédula')));
    });

    test('no se puede deslizar entre pasos', () {
      // Deslizar se saltaría la validación del paso sin que nadie lo note.
      expect(alta, contains('NeverScrollableScrollPhysics'));
    });

    test('atrás retrocede de paso antes de salir', () {
      final atras = alta.substring(
        alta.indexOf('void _atras()'),
        alta.indexOf('Future<void> _guardar('),
      );
      expect(atras, contains('if (_paso == 0)'));
      expect(atras, contains('_paso--'));
    });

    test('el gesto de atrás del sistema hace lo mismo', () {
      // Salirse del alta entera por darle atrás una vez de más es la forma más
      // tonta de perder un conductor.
      expect(alta, contains('PopScope'));
      expect(alta, contains('canPop: _paso == 0'));
      expect(alta, contains('if (!salio) _atras()'));
    });

    test('la barra de progreso sigue midiendo datos, no pasos', () {
      // La pregunta del conductor es "¿cuánto me falta para que me habiliten?",
      // y esa no la responde ir por la pantalla 2 de 3.
      expect(alta, contains('_totalHitos = 2 + AltaConductorViewModel.documentosRequeridos'));
      expect(alta, contains('hechos: _completados(vm)'));
    });

    test('cambiar la marca limpia el modelo', () {
      final elegir = alta.substring(
        alta.indexOf('void _elegirMarca('),
        alta.indexOf('bool _valido('),
      );
      expect(elegir, contains('_modelo = null'));
    });

    test('el modelo va deshabilitado mientras no haya marca', () {
      expect(alta, contains('onChanged: modelos.isEmpty ? null : onModelo'));
    });

    test('se envía el vehículo compuesto', () {
      expect(alta, contains('vehiculo: _vehiculo!'));
    });

    test('el paso de revisión deja volver a cualquier paso', () {
      expect(alta, contains('onIrAPaso'));
    });
  });
}

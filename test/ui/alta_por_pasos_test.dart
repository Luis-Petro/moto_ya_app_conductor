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
      // la cédula, que todavía no ha llegado.
      final valido = alta.substring(
        alta.indexOf('bool _pasoValido('),
        alta.indexOf('void _siguiente()'),
      );
      expect(valido, contains('0 => _motoLista'));
      expect(valido, contains('1 => vm.tieneCedula'));
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

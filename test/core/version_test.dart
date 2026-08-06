import 'package:app_conductor/ui/core/format/version.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comparar versiones como texto diría que 1.9.3 es mayor que 1.10.0 y el banner
/// nunca aparecería en la actualización que más importa.
void main() {
  test('compara por componentes numéricos, no alfabéticamente', () {
    expect(compararVersiones('1.10.0', '1.9.3'), greaterThan(0));
    expect(compararVersiones('1.9.3', '1.10.0'), lessThan(0));
  });

  test('versiones iguales empatan', () {
    expect(compararVersiones('1.2.3', '1.2.3'), 0);
  });

  test('componentes ausentes valen cero', () {
    expect(compararVersiones('1.2', '1.2.0'), 0);
    expect(compararVersiones('1.2', '1.2.1'), lessThan(0));
  });

  test('ignora sufijos no numéricos', () {
    expect(compararVersiones('1.4.0-beta', '1.4.0'), 0);
    expect(compararVersiones('2.0.0-rc1', '1.9.9'), greaterThan(0));
  });
}


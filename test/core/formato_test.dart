import 'package:app_conductor/ui/core/format/formato.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_CO');
  });

  group('Formato.moneda', () {
    test('formatea pesos sin decimales', () {
      expect(Formato.moneda(10000), contains('10.000'));
      expect(Formato.moneda(null), '—');
    });
  });

  group('Formato.diferencia', () {
    test('muestra el signo correcto', () {
      expect(Formato.diferencia(12000, 10000), contains('+'));
      expect(Formato.diferencia(8000, 10000), contains('-'));
    });
  });
}


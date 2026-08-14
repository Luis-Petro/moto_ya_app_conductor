import 'package:app_conductor/data/services/dispositivo_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// El identificador de la instalaciÃ³n tiene que ser **el mismo** entre
/// arranques: si cambiara, cada entrada parecerÃ­a un telÃ©fono nuevo y el panel
/// verÃ­a una lista de dispositivos fantasma en vez de la seÃ±al que busca (varias
/// cuentas en un mismo equipo).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('genera un identificador la primera vez y lo reutiliza', () async {
    final servicio = DispositivoService();

    final primero = await servicio.id();
    expect(primero, isNotEmpty);

    // Instancia nueva = arranque nuevo: tiene que leer el que ya se guardÃ³.
    final otroArranque = DispositivoService();
    expect(await otroArranque.id(), primero);
  });

  test('tiene forma de UUID v4', () async {
    final id = await DispositivoService().id();

    // Un identificador propio, no el del sistema operativo: Play trata los de
    // hardware como dato sensible y no responden mejor la Ãºnica pregunta que se
    // hace aquÃ­.
    expect(
      id,
      matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
  });

  test('dos instalaciones distintas no comparten identificador', () async {
    final uno = await DispositivoService().id();
    FlutterSecureStorage.setMockInitialValues({});
    final otro = await DispositivoService().id();

    expect(uno, isNot(otro));
  });
}

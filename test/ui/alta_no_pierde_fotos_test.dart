import 'dart:io';

import 'package:app_conductor/data/repositories/conductor_repository.dart';
import 'package:app_conductor/data/repositories/municipio_repository.dart';
import 'package:app_conductor/data/repositories/usuario_repository.dart';
import 'package:app_conductor/data/services/api_result.dart';
import 'package:app_conductor/data/services/borrador_alta.dart';
import 'package:app_conductor/data/services/location_service.dart';
import 'package:app_conductor/domain/models/conductor.dart';
import 'package:app_conductor/domain/models/municipio.dart';
import 'package:app_conductor/domain/models/rol.dart';
import 'package:app_conductor/domain/models/usuario.dart';
import 'package:app_conductor/ui/features/alta_conductor/alta_conductor_view_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Conductores extends Mock implements ConductorRepository {}

class _Ubicacion extends Mock implements LocationService {}

class _Municipios extends Mock implements MunicipioRepository {}

class _Usuarios extends Mock implements UsuarioRepository {}

/// El alta de conductor **no pierde las fotos**.
///
/// El reporte fue: "agregó los documentos en el registro y luego faltaban todos".
/// Había tres caminos para llegar ahí, y los tres compilaban y no daban error:
///
/// 1. La cédula no subía (señal) → el repintado del error mandaba al Inicio,
///    porque el perfil ya estaba creado, y con la pantalla se iban las fotos.
/// 2. Las otras tres fotos fallaban y el resultado se descartaba.
/// 3. Salir del alta antes de "Enviar" —o que Android matara la app con la
///    cámara abierta— borraba todo lo que solo vivía en memoria.
void main() {
  late Directory tmp;
  late _Conductores conductores;
  late _Usuarios usuarios;
  late BorradorAlta borrador;
  Conductor? perfil;

  const cuenta = Usuario(id: 7, nombre: 'Jhon Pérez', rol: Rol.conductor);
  const creado =
      Conductor(id: 1, usuarioId: 7, vehiculo: 'Bajaj Boxer', placa: 'ABC12D');

  File foto(String nombre) =>
      File('${tmp.path}/$nombre.jpg')..writeAsBytesSync(List.filled(64, 7));

  AltaConductorViewModel nuevoVm() {
    final municipios = _Municipios();
    when(() => municipios.disponibles())
        .thenAnswer((_) async => const Ok(<Municipio>[]));
    when(() => municipios.porId(any())).thenReturn(null);
    final ubicacion = _Ubicacion();
    when(() => ubicacion.obtenerUbicacion())
        .thenAnswer((_) async => const LocationResult(LocationOutcome.error));
    return AltaConductorViewModel(
      conductores,
      ubicacion,
      municipios,
      usuarios,
      borrador: borrador,
    );
  }

  setUpAll(() {
    registerFallbackValue(const LatLng(0, 0));
    registerFallbackValue(MultipartFile.fromBytes(const [1]));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('alta_test');
    borrador = BorradorAlta(directorio: () async => tmp);
    perfil = null;

    conductores = _Conductores();
    when(() => conductores.conductor).thenAnswer((_) => perfil);
    when(() => conductores.perfilCompleto)
        .thenAnswer((_) => perfil?.perfilCompleto ?? false);
    when(() => conductores.cargar(forzar: any(named: 'forzar')))
        .thenAnswer(
            (_) async => const Err(Failure('sin perfil', statusCode: 404)));
    when(() => conductores.crearPerfil(
          licencia: any(named: 'licencia'),
          vehiculo: any(named: 'vehiculo'),
          placa: any(named: 'placa'),
          ubicacion: any(named: 'ubicacion'),
        )).thenAnswer((_) async {
      perfil = creado;
      return const Ok(creado);
    });
    when(() => conductores.subirCedula(any()))
        .thenAnswer((_) async => const Ok(null));
    when(() => conductores.subirSelfie(any()))
        .thenAnswer((_) async => const Ok(null));
    when(() => conductores.subirPapelesMoto(any()))
        .thenAnswer((_) async => const Ok(null));
    when(() => conductores.subirFotoMoto(any()))
        .thenAnswer((_) async => const Ok(null));

    usuarios = _Usuarios();
    when(() => usuarios.perfil()).thenAnswer((_) async => const Ok(cuenta));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<bool> enviar(AltaConductorViewModel vm) =>
      vm.guardar(vehiculo: 'Bajaj Boxer', placa: 'ABC12D');

  group('Si la cédula no sube', () {
    test('la pantalla no salta al Inicio y las fotos siguen ahí', () async {
      when(() => conductores.subirCedula(any())).thenAnswer((_) async =>
          const Err(Failure('Sin conexión.', kind: FailureKind.network)));
      final vm = nuevoVm();
      await vm.cargar();
      await vm.elegirFoto(DocumentoConductor.cedula, foto('cedula'));
      await vm.elegirFoto(DocumentoConductor.selfie, foto('selfie'));

      expect(await enviar(vm), isFalse);

      // El perfil ya se creó: `perfilCompleto` es cierto. La pantalla decide el
      // salto con `yaTeniaPerfil`, que no cambia a mitad del envío.
      expect(conductores.perfilCompleto, isTrue);
      expect(vm.yaTeniaPerfil, isFalse);
      expect(vm.cedula, isNotNull);
      expect(vm.selfie, isNotNull);
      expect(vm.error, contains('Tus fotos siguen guardadas'));
    });

    test('reintentar no vuelve a crear el perfil', () async {
      var intentos = 0;
      when(() => conductores.subirCedula(any())).thenAnswer((_) async =>
          ++intentos == 1 ? const Err(Failure('cortó')) : const Ok(null));
      final vm = nuevoVm();
      await vm.cargar();
      await vm.elegirFoto(DocumentoConductor.cedula, foto('cedula'));

      expect(await enviar(vm), isFalse);
      expect(await enviar(vm), isTrue);

      verify(() => conductores.crearPerfil(
            licencia: any(named: 'licencia'),
            vehiculo: any(named: 'vehiculo'),
            placa: any(named: 'placa'),
            ubicacion: any(named: 'ubicacion'),
          )).called(1);
    });
  });

  group('Si las otras fotos no suben', () {
    test('se dice cuáles, en vez de dar el alta por completa', () async {
      when(() => conductores.subirSelfie(any()))
          .thenAnswer((_) async => const Err(Failure('cortó')));
      final vm = nuevoVm();
      await vm.cargar();
      await vm.elegirFoto(DocumentoConductor.cedula, foto('cedula'));
      await vm.elegirFoto(DocumentoConductor.selfie, foto('selfie'));
      await vm.elegirFoto(DocumentoConductor.fotoMoto, foto('moto'));

      expect(await enviar(vm), isTrue,
          reason: 'Solo la cédula bloquea el envío.');
      expect(vm.documentosNoSubidos, ['selfie tuya']);
      // Dos intentos por foto antes de darla por fallida.
      verify(() => conductores.subirSelfie(any())).called(2);
    });

    test('el reintento sube solo las que faltaban', () async {
      var selfieFalla = true;
      when(() => conductores.subirSelfie(any())).thenAnswer((_) async =>
          selfieFalla ? const Err(Failure('cortó')) : const Ok(null));
      final vm = nuevoVm();
      await vm.cargar();
      await vm.elegirFoto(DocumentoConductor.cedula, foto('cedula'));
      await vm.elegirFoto(DocumentoConductor.selfie, foto('selfie'));
      await vm.elegirFoto(DocumentoConductor.fotoMoto, foto('moto'));
      await enviar(vm);

      selfieFalla = false;
      expect(await vm.reintentarDocumentos(), isTrue);
      expect(vm.documentosNoSubidos, isEmpty);
      verify(() => conductores.subirCedula(any())).called(1);
      verify(() => conductores.subirFotoMoto(any())).called(1);
    });
  });

  group('El borrador sobrevive a salir de la pantalla', () {
    test('las fotos y los datos vuelven al abrir el alta otra vez', () async {
      final primero = nuevoVm();
      await primero.cargar();
      await primero.elegirFoto(DocumentoConductor.cedula, foto('cedula'));
      await primero.elegirFoto(
          DocumentoConductor.tarjetaPropiedad, foto('tarjeta'));
      primero.recordarCampos(
        marca: 'Bajaj',
        modelo: 'Boxer CT 100',
        marcaLibre: '',
        modeloLibre: '',
        placa: 'ABC12D',
        licencia: '',
        paso: 1,
      );
      // Deja terminar la escritura, que no se espera desde la pantalla.
      await Future<void>.delayed(Duration.zero);
      primero.dispose();

      final segundo = nuevoVm();
      await segundo.cargar();

      expect(segundo.cedula?.existsSync(), isTrue);
      expect(segundo.papelesMoto?.existsSync(), isTrue);
      expect(segundo.borrador.marca, 'Bajaj');
      expect(segundo.borrador.placa, 'ABC12D');
      expect(segundo.borrador.paso, 1);
      expect(segundo.documentosListos, 2);
    });

    test('la foto se copia fuera de la caché de la cámara', () async {
      final vm = nuevoVm();
      await vm.cargar();
      final original = foto('cedula');
      await vm.elegirFoto(DocumentoConductor.cedula, original);

      expect(vm.cedula!.path, isNot(original.path));
      expect(vm.cedula!.path, contains('alta_7'));
    });

    test('una foto cuyo archivo ya no existe no se cuenta como lista',
        () async {
      final vm = nuevoVm();
      await vm.cargar();
      await vm.elegirFoto(DocumentoConductor.cedula, foto('cedula'));
      vm.cedula!.deleteSync();
      vm.dispose();

      final otro = nuevoVm();
      await otro.cargar();
      expect(otro.cedula, isNull);
      expect(otro.tieneCedula, isFalse);
    });

    test('es de la cuenta: otra persona en el mismo teléfono no lo hereda',
        () async {
      final vm = nuevoVm();
      await vm.cargar();
      await vm.elegirFoto(DocumentoConductor.cedula, foto('cedula'));
      vm.dispose();

      when(() => usuarios.perfil()).thenAnswer((_) async =>
          const Ok(Usuario(id: 8, nombre: 'Otra Persona', rol: Rol.conductor)));
      final otro = nuevoVm();
      await otro.cargar();
      expect(otro.cedula, isNull);
    });

    test('se borra cuando el alta ya se envió', () async {
      final vm = nuevoVm();
      await vm.cargar();
      await vm.elegirFoto(DocumentoConductor.cedula, foto('cedula'));
      expect(await enviar(vm), isTrue);
      await vm.cerrarBorrador();

      expect((await borrador.leer(7)).vacio, isTrue);
      expect(Directory('${tmp.path}/alta_7').existsSync(), isFalse);
    });
  });

  group('Android mató la app con la cámara abierta', () {
    test('la foto recuperada va al documento para el que se abrió', () async {
      final antes = nuevoVm();
      await antes.cargar();
      await antes.anotarCaptura(DocumentoConductor.selfie);
      antes.dispose(); // la app muere aquí

      final despues = nuevoVm();
      // La pantalla pide la foto perdida nada más montarse, antes de que
      // termine la carga: tiene que esperar a saber para qué documento era.
      final recuperacion = despues.recuperarFotoPerdida(foto('perdida'));
      await despues.cargar();
      await recuperacion;

      expect(despues.selfie, isNotNull);
      expect(despues.cedula, isNull);
      expect(despues.borrador.capturaPendiente, isNull);
    });

    test('sin captura apuntada, una foto suelta no se asigna a nada', () async {
      final vm = nuevoVm();
      await vm.cargar();
      await vm.recuperarFotoPerdida(foto('suelta'));
      expect(vm.documentosListos, 0);
    });
  });

  group('Sin señal al abrir', () {
    test('no se enseña el alta vacía: no se sabe si ya tiene perfil', () async {
      // A un conductor ya registrado le salía el formulario en blanco con sus
      // cuatro documentos "pendientes", como si se le hubiera borrado todo.
      when(() => conductores.cargar(forzar: any(named: 'forzar'))).thenAnswer(
          (_) async =>
              const Err(Failure('Sin conexión.', kind: FailureKind.network)));
      final vm = nuevoVm();
      await vm.cargar();

      expect(vm.errorCarga, 'Sin conexión.');
      expect(vm.errorCargaEsRed, isTrue);
      expect(vm.cargando, isFalse);
    });

    test('un 404 sí es "sin perfil": el alta se abre', () async {
      when(() => conductores.cargar(forzar: any(named: 'forzar'))).thenAnswer(
          (_) async => const Err(Failure('No existe', statusCode: 404)));
      final vm = nuevoVm();
      await vm.cargar();
      expect(vm.errorCarga, isNull);
    });
  });

  test('con el perfil ya creado al abrir, el alta se salta', () async {
    perfil = creado;
    final vm = nuevoVm();
    await vm.cargar();
    expect(vm.yaTeniaPerfil, isTrue);
  });

  test('la pantalla decide el salto con yaTeniaPerfil, no con perfilCompleto',
      () {
    final pantalla = File(
      'lib/ui/features/alta_conductor/alta_conductor_screen.dart',
    ).readAsStringSync();
    expect(pantalla, contains('vm.yaTeniaPerfil && !_saltoAplicado'));
    expect(pantalla, isNot(contains('vm.perfilCompleto && !_saltoAplicado')));
    // Y pide la foto perdida al montarse.
    expect(pantalla, contains('retrieveLostData()'));
  });
}

import 'package:app_conductor/data/services/banner_descartes.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage storage;
  late BannerDescartes descartes;
  String? guardado;

  setUp(() {
    storage = _MockStorage();
    descartes = BannerDescartes(storage);
    guardado = null;
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((i) async => guardado = i.namedArguments[#value] as String?);
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  });

  void conGuardado(String? raw) {
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => raw);
  }

  test('las claves llevan el aviso y su publicación', () async {
    conGuardado('7:1000,8:2000');

    expect(await descartes.descartados(), {'7:1000', '8:2000'});
  });

  test('un descarte del formato viejo se ignora', () async {
    // Sin instante no se sabe a qué publicación se refería. El precio de
    // ignorarlo es enseñar el aviso una vez; el de conservarlo es ocultar para
    // siempre uno que el administrador acaba de publicar.
    conGuardado('7,8:2000');

    expect(await descartes.descartados(), {'8:2000'});
  });

  test('descartar olvida los avisos que ya no llegan del servidor', () async {
    conGuardado('7:1000,8:2000');

    await descartes.descartar('9:3000', idsVigentes: {8, 9});

    // El 7 ya no existe en el panel: su descarte no sirve para nada y solo hace
    // crecer la lista.
    expect(guardado, isNot(contains('7:1000')));
    expect(guardado, contains('8:2000'));
    expect(guardado, contains('9:3000'));
  });

  test('sin ids vigentes solo sobrevive el descarte nuevo', () async {
    conGuardado('7:1000');

    await descartes.descartar('9:3000');

    expect(guardado, '9:3000');
  });

  test('cerrar sesión lo borra todo', () async {
    conGuardado('7:1000');
    await descartes.descartados();

    await descartes.borrar();
    conGuardado(null);

    expect(await descartes.descartados(), isEmpty);
    verify(() => storage.delete(key: 'banners_descartados')).called(1);
  });
}

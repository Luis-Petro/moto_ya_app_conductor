import 'package:app_conductor/data/repositories/auth_repository.dart';
import 'package:app_conductor/data/services/auth_service.dart';
import 'package:app_conductor/data/services/api_result.dart';
import 'package:app_conductor/data/services/notificacion_service.dart';
import 'package:app_conductor/data/services/push_service.dart';
import 'package:app_conductor/data/services/session_storage.dart';
import 'package:app_conductor/data/services/social_auth_service.dart';
import 'package:app_conductor/domain/models/rol.dart';
import 'package:app_conductor/domain/models/sesion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockSocial extends Mock implements SocialAuthService {}

class _MockSession extends Mock implements SessionStorage {}

class _MockNotificaciones extends Mock implements NotificacionService {}

class _MockPush extends Mock implements PushService {}

class _FakeSesion extends Fake implements Sesion {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSesion());
  });

  late _MockAuthService auth;
  late _MockSocial social;
  late _MockSession session;
  late _MockNotificaciones notificaciones;
  late _MockPush push;
  late AuthRepository repo;

  const sesion = Sesion(token: 'jwt-123', usuarioId: 7, rol: Rol.cliente);

  setUp(() {
    auth = _MockAuthService();
    social = _MockSocial();
    session = _MockSession();
    notificaciones = _MockNotificaciones();
    push = _MockPush();
    repo = AuthRepository(auth, social, session, notificaciones, push);

    when(() => session.guardar(any())).thenAnswer((_) async {});
    when(() => push.obtenerToken()).thenAnswer((_) async => null);
  });

  test('login exitoso persiste la sesiÃ³n y queda autenticado', () async {
    when(() => auth.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => const Ok(sesion));

    final res = await repo.loginEmail('marta@correo.com', 'secreta');

    expect(res.isSuccess, isTrue);
    expect(repo.estaAutenticado, isTrue);
    expect(repo.sesion?.token, 'jwt-123');
    verify(() => session.guardar(sesion)).called(1);
  });

  test('login fallido no autentica', () async {
    when(() => auth.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => const Err(Failure('Credenciales incorrectas')));

    final res = await repo.loginEmail('x@y.com', 'mala');

    expect(res.isSuccess, isFalse);
    expect(repo.estaAutenticado, isFalse);
    verifyNever(() => session.guardar(any()));
  });

  test('sesionExpirada limpia la sesiÃ³n', () async {
    when(() => session.borrar()).thenAnswer((_) async {});
    when(() => auth.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => const Ok(sesion));
    await repo.loginEmail('a@b.com', '123');
    expect(repo.estaAutenticado, isTrue);

    await repo.sesionExpirada();

    expect(repo.estaAutenticado, isFalse);
    verify(() => session.borrar()).called(1);
  });
}


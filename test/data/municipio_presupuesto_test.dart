import 'dart:async';

import 'package:app_conductor/data/repositories/usuario_repository.dart';
import 'package:app_conductor/data/services/api_result.dart';
import 'package:app_conductor/data/services/usuario_service.dart';
import 'package:app_conductor/domain/models/rol.dart';
import 'package:app_conductor/domain/models/usuario.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resolver el municipio es **una** cosa, y se pide.
///
/// La capa de lugares de los mapas se limitaba a mirar la caché en memoria
/// treinta veces a ver si alguien la había llenado. En esta app el perfil lo
/// pide el Inicio con `unawaited`, así que si el mapa se montaba primero nadie
/// la llenaba a tiempo: mapa sin marcadores, y ni siquiera un enlace de
/// reintentar que pudiera cambiar el resultado.
///
/// El presupuesto acota **el reloj, no los intentos**: con `connectTimeout` de
/// 12 s más `receiveTimeout` de 20 s, seis intentos escalonados son hasta tres
/// minutos de esqueleto antes de decir que algo falló.
void main() {
  Usuario conMunicipio(int? id) =>
      Usuario(id: 1, nombre: 'Jhon', rol: Rol.conductor, municipioId: id);

  group('Resolver el municipio', () {
    test('lo pide cuando no está en caché', () async {
      final servicio = _PerfilFake(conMunicipio(7));
      final repo = UsuarioRepository(servicio);

      expect(await repo.resolverMunicipio(), 7);
      expect(servicio.llamadas, 1, reason: 'tenía que preguntar, no mirar');
    });

    test('con el perfil ya en caché no cuesta ninguna petición', () async {
      final servicio = _PerfilFake(conMunicipio(7));
      final repo = UsuarioRepository(servicio);
      await repo.perfil();

      expect(await repo.resolverMunicipio(), 7);
      expect(servicio.llamadas, 1,
          reason: 'el camino normal no puede pagar dos veces');
    });

    test('se rinde dentro del presupuesto aunque el perfil no responda',
        () async {
      // El caso que dejaba el esqueleto girando: una petición que no vuelve. El
      // presupuesto se mide en reloj, así que no depende de cuántos intentos
      // queden ni de lo que tarde el cliente HTTP en rendirse.
      final servicio = _PerfilQueNoResponde();
      final repo = UsuarioRepository(servicio);
      final reloj = Stopwatch()..start();

      final id = await repo.resolverMunicipio(
          presupuesto: const Duration(milliseconds: 300));

      expect(id, isNull);
      expect(reloj.elapsed, lessThan(const Duration(seconds: 3)),
          reason: 'el presupuesto no acotó nada');
    });

    test('reintenta pidiendo de nuevo, no releyendo la caché', () async {
      // El perfil llega, pero sin municipio. Sin `forzar` en los reintentos, la
      // caché devolvería ese mismo usuario sin municipio para siempre y la
      // escalera sería una espera decorativa.
      final servicio = _PerfilFake(conMunicipio(null));
      final repo = UsuarioRepository(servicio);
      final reloj = Stopwatch()..start();

      final id = await repo.resolverMunicipio(
          presupuesto: const Duration(milliseconds: 1500));

      expect(id, isNull);
      expect(servicio.llamadas, greaterThan(1),
          reason: 'tenía que volver a preguntar antes de rendirse');
      expect(reloj.elapsed, lessThan(const Duration(seconds: 3)),
          reason: 'la espera escalonada tiene que caber en el presupuesto');
    });

    test('dos pantallas a la vez comparten un solo intento', () async {
      // Al abrir la app, el mapa del Inicio y el del pedido activo arrancan casi
      // al mismo tiempo. Sin esto serían dos peticiones idénticas.
      final servicio = _PerfilFake(conMunicipio(7),
          demora: const Duration(milliseconds: 50));
      final repo = UsuarioRepository(servicio);

      final resultados = await Future.wait(
          [repo.resolverMunicipio(), repo.resolverMunicipio()]);

      expect(resultados, [7, 7]);
      expect(servicio.llamadas, 1);
    });

    test('un intento agotado no deja la app inservible', () async {
      // Si el intento fallido quedara memorizado, el enlace de reintentar
      // devolvería el mismo `null` para siempre.
      final servicio = _PerfilQueFallaAlPrincipio(conMunicipio(7));
      final repo = UsuarioRepository(servicio);

      final primero = await repo.resolverMunicipio(
          presupuesto: const Duration(milliseconds: 300));
      expect(primero, isNull);

      servicio.yaPuedeResponder = true;
      expect(await repo.resolverMunicipio(), 7,
          reason: 'el segundo intento tiene que pedir de verdad');
    });
  });
}

class _PerfilFake extends Fake implements UsuarioService {
  _PerfilFake(this.usuario, {this.demora});

  final Usuario usuario;
  final Duration? demora;
  int llamadas = 0;

  @override
  Future<Result<Usuario>> obtenerPerfil() async {
    llamadas++;
    if (demora != null) await Future<void>.delayed(demora!);
    return Ok(usuario);
  }
}

/// La petición que nunca vuelve: lo que el presupuesto de reloj existe para
/// acotar.
class _PerfilQueNoResponde extends Fake implements UsuarioService {
  @override
  Future<Result<Usuario>> obtenerPerfil() =>
      Completer<Result<Usuario>>().future;
}

class _PerfilQueFallaAlPrincipio extends Fake implements UsuarioService {
  _PerfilQueFallaAlPrincipio(this.usuario);

  final Usuario usuario;
  bool yaPuedeResponder = false;

  @override
  Future<Result<Usuario>> obtenerPerfil() async {
    if (!yaPuedeResponder) {
      return const Err(Failure('sin conexión', kind: FailureKind.network));
    }
    return Ok(usuario);
  }
}

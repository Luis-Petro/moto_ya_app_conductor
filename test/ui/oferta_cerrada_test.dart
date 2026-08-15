import 'dart:async';

import 'package:app_conductor/data/repositories/pedido_repository.dart';
import 'package:app_conductor/data/services/api_result.dart';
import 'package:app_conductor/data/services/ofertas_service.dart';
import 'package:app_conductor/domain/models/oferta.dart';
import 'package:app_conductor/domain/models/pedido.dart';
import 'package:app_conductor/ui/features/pedido_entrante/pedido_entrante_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abrir la notificación de un pedido que ya no está no es un fallo de red.
///
/// El backend responde **403 "No participas en este pedido"** cuando el pedido
/// lo tomó otro conductor o el cliente lo canceló, y eso caía en el mismo estado
/// que quedarse sin internet: nube tachada y un "Reintentar" que iba a fallar
/// exactamente igual las veces que lo tocaran.
void main() {
  PedidoEntranteViewModel vmCon(Failure fallo) => PedidoEntranteViewModel(
        _RepoQueFalla(fallo),
        42,
        _OfertasMudas(),
        segundosIniciales: 60,
      );

  test('un 403 abre el estado terminal, no el de error', () async {
    final vm = vmCon(const Failure('No participas en este pedido',
        statusCode: 403, kind: FailureKind.server));

    await vm.cargar();

    expect(vm.estado, EstadoEntrante.noDisponible);
  });

  test('un 404 también', () async {
    final vm = vmCon(const Failure('No se encontró el recurso',
        statusCode: 404, kind: FailureKind.notFound));

    await vm.cargar();

    expect(vm.estado, EstadoEntrante.noDisponible);
  });

  test('sin conexión sigue siendo error con reintento', () async {
    final vm = vmCon(const Failure('Sin conexión. Verifica tu internet.',
        kind: FailureKind.network));

    await vm.cargar();

    expect(vm.estado, EstadoEntrante.error);
    expect(vm.error, isNotNull);
  });

  test('sin evento previo el motivo no escoge una de las dos causas', () async {
    // El 403 no distingue "la tomó otro" de "el cliente canceló". Nombrar una
    // haría que el conductor sacara conclusiones sobre su velocidad de
    // respuesta a partir de un dato inventado.
    final vm = vmCon(const Failure('No participas', statusCode: 403));

    await vm.cargar();

    expect(vm.motivoNoDisponible, contains('otro conductor'));
    expect(vm.motivoNoDisponible, contains('cancelara'));
  });
}

class _RepoQueFalla implements PedidoRepository {
  _RepoQueFalla(this.fallo);

  final Failure fallo;

  @override
  Future<Result<Pedido>> detalle(int pedidoId) async => Err<Pedido>(fallo);

  @override
  Future<Result<List<Oferta>>> ofertas() async => const Ok<List<Oferta>>([]);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// No emite nada: reproduce la apertura en frío desde la notificación, sin
/// ningún evento de cierre recibido antes.
class _OfertasMudas implements OfertasService {
  @override
  Stream<EventoOferta> connect() => const Stream<EventoOferta>.empty();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

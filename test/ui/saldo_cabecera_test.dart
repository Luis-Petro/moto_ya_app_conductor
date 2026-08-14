import 'package:app_conductor/domain/models/conductor.dart';
import 'package:app_conductor/ui/core/theme/app_colors.dart';
import 'package:app_conductor/ui/features/perfil/perfil_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El saldo de la cabecera del perfil, en sus tres casos.
///
/// `deudaActual` llega **con signo**: en positivo son comisiones pendientes y en
/// negativo es saldo a favor (un incentivo o una corrección del administrador).
/// La cabecera pintaba el rótulo `DEUDA` fijo, así que a un conductor con saldo a
/// favor la pantalla que dice si puede trabajar le decía que debía dinero — y la
/// Billetera, sobre el mismo número, le decía lo contrario.
void main() {
  Conductor conductorCon(double deuda, {EstadoConductor? estado}) => Conductor(
    id: 1,
    usuarioId: 1,
    deudaActual: deuda,
    estado: estado ?? EstadoConductor.activo,
  );

  Future<void> montar(
    WidgetTester tester,
    Conductor conductor, {
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaldoCabecera(conductor: conductor, onTap: onTap ?? () {}),
        ),
      ),
    );
  }

  testWidgets('con deuda dice DEUDA', (tester) async {
    await montar(tester, conductorCon(1200));

    expect(find.text('DEUDA'), findsOneWidget);
    expect(find.text('A FAVOR'), findsNothing);
    expect(find.textContaining('1.200'), findsOneWidget);
  });

  testWidgets('con saldo a favor dice A FAVOR, en positivo y en verde', (
    tester,
  ) async {
    await montar(tester, conductorCon(-3000));

    expect(find.text('A FAVOR'), findsOneWidget);
    // Ni la palabra "deuda" ni un valor negativo en ninguna parte: es la buena
    // noticia y se lee como tal.
    expect(find.text('DEUDA'), findsNothing);
    expect(find.textContaining('-'), findsNothing);
    expect(find.textContaining('3.000'), findsOneWidget);

    final valor = tester.widget<Text>(find.textContaining('3.000'));
    expect(valor.style?.color, AppColors.success);
  });

  testWidgets('al día no pinta nada', (tester) async {
    // Un `DEUDA $ 0` obliga a leer un número para enterarse de que no pasa nada,
    // y le quita sitio al único dato que importa aquí: el estado de la cuenta.
    await montar(tester, conductorCon(0));

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('bloqueado por deuda: el valor va en rojo', (tester) async {
    // El bloqueo manda sobre el signo: si no puede recibir pedidos, el número que
    // lo explica se ve como lo que es.
    await montar(
      tester,
      conductorCon(20000, estado: EstadoConductor.bloqueadoPorDeuda),
    );

    final valor = tester.widget<Text>(find.textContaining('20.000'));
    expect(valor.style?.color, AppColors.danger);
  });

  testWidgets('el bloque es tocable', (tester) async {
    var toques = 0;
    await montar(tester, conductorCon(1200), onTap: () => toques++);

    await tester.tap(find.text('DEUDA'));
    expect(toques, 1);
  });
}

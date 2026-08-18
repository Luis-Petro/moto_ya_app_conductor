import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda del **sistema visual**: ninguna pantalla declara su propia
/// tipografía ni su propio color.
///
/// No es un test de estilo. Al escribirse, las pantallas del conductor tenían
/// **213 `fontSize` escritos a mano** repartidos en 29 archivos —la billetera
/// sola llevaba 36— y cada pantalla nueva inventaba los suyos. Eso no da error,
/// no se ve en una revisión de código y la jerarquía se deshace sola, una
/// pantalla cada vez.
///
/// Lo mismo con el color: `AppColors` existía y aun así se colaban `white70`
/// sobre el navy de marca (sin token para ese caso) y un `black45` en el perfil.
///
/// La lista de exentos es **deuda declarada**, no una puerta trasera: cada
/// pantalla sale de ella al migrarse y la última tarea del cambio es dejarla
/// vacía. Un test que naciera en rojo se apagaría con `skip` y no vigilaría
/// nada; uno que nace con la deuda a la vista se vacía solo.
///
/// **Cuando quede vacía, las constantes se conservan.** Son ellas las que
/// documentan la regla: una pantalla nueva que traiga su propio `fontSize`
/// tiene que fallar aquí, no añadirse a una lista.
void main() {
  /// Los únicos colores de Material admitidos.
  ///
  /// `white` porque es lo que va sobre el naranja y el navy, y no tiene token
  /// propio: es blanco puro, no un gris de la paleta. `transparent` porque no
  /// es un color, es la ausencia de uno.
  ///
  /// Fuera de aquí queda `white70` a propósito. Sobre el navy no es un fallo de
  /// contraste (da por encima de 7:1), pero sin token para "texto secundario
  /// sobre navy" cada pantalla lo resuelve a su manera y esta regla deja de
  /// poder aplicarse sin criterio. Ese caso es `AppColors.onAccentMuted`.
  const permitidos = {'white', 'transparent'};

  /// Pantallas que todavía declaran su tipografía a mano.
  ///
  /// Se vacía por bloques, en el orden de `tasks.md`: Inicio, acceso, alta,
  /// pedido, y por último historial/dinero/perfil.
  const exentosTipografia = <String>{
    'billetera/billetera_screen.dart',
    'feedback/feedback_screen.dart',
    'historial/historial_screen.dart',
    'pedido_activo/pedido_activo_screen.dart',
    'pedido_detalle/pedido_detalle_screen.dart',
    'pedido_entrante/pedido_entrante_screen.dart',
    'perfil/documentos_screen.dart',
    'perfil/perfil_screen.dart',
  };

  /// Pantallas que todavía declaran algún color de Material. Queda el
  /// `black45` del perfil; el del Inicio ya salió.
  const exentosColor = <String>{'perfil/perfil_screen.dart'};

  List<File> pantallas() => Directory('lib/ui/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String ruta(File f) => f.path.replaceAll(r'\', '/');

  String relativa(File f) {
    final r = ruta(f);
    const marca = 'lib/ui/features/';
    final i = r.indexOf(marca);
    return i == -1 ? r : r.substring(i + marca.length);
  }

  // El límite de palabra distingue `Colors.white` de `AppColors.white`.
  final usaColorMaterial =
      RegExp(r'(^|[^A-Za-z0-9_])Colors\.([A-Za-z][A-Za-z0-9]*)');
  final literalDeColor = RegExp(r'Color\(0x');
  final declaraTamano = RegExp(r'\bfontSize:');

  test('hay pantallas que revisar', () {
    // Si un renombrado de carpeta deja la lista vacía, todo lo demás pasaría
    // por no tener nada que mirar.
    expect(pantallas(), isNotEmpty);
  });

  test('las listas de exentos solo nombran pantallas que existen', () {
    // Sin este caso, una exención con el nombre mal escrito —o la de una
    // pantalla ya borrada— se quedaría ahí para siempre pareciendo deuda viva,
    // y al migrar la última nadie sabría por qué la lista no se vacía.
    final existentes = pantallas().map(relativa).toSet();
    expect(
      {...exentosTipografia, ...exentosColor}.difference(existentes),
      isEmpty,
      reason: 'Hay exenciones que no corresponden a ninguna pantalla.',
    );
  });

  test('ninguna pantalla declara un tamaño de fuente', () {
    final infractores = <String>[];
    for (final f in pantallas()) {
      final nombre = relativa(f);
      if (exentosTipografia.contains(nombre)) continue;
      final veces = declaraTamano.allMatches(f.readAsStringSync()).length;
      if (veces > 0) infractores.add('$nombre ($veces)');
    }
    expect(
      infractores,
      isEmpty,
      reason: 'Estas pantallas declaran su propia tipografía en vez de usar un '
          'rol de AppText (display, title, subtitle, body, caption, cta, '
          'money, moneySm, label):\n${infractores.join("\n")}',
    );
  });

  test('ninguna pantalla escribe un literal de color', () {
    final infractores = [
      for (final f in pantallas())
        if (literalDeColor.hasMatch(f.readAsStringSync())) relativa(f),
    ];
    expect(
      infractores,
      isEmpty,
      reason: 'Un `Color(0xFF…)` en una pantalla es un color que no está en la '
          'paleta y que nadie más puede reutilizar. Añádelo a AppColors:\n'
          '${infractores.join("\n")}',
    );
  });

  test('ninguna pantalla usa un color de Material fuera de los permitidos', () {
    final infractores = <String>[];
    for (final f in pantallas()) {
      final nombre = relativa(f);
      if (exentosColor.contains(nombre)) continue;
      final usados = usaColorMaterial
          .allMatches(f.readAsStringSync())
          .map((m) => m.group(2)!)
          .where((c) => !permitidos.contains(c))
          .toSet();
      if (usados.isNotEmpty) infractores.add('$nombre: ${usados.join(", ")}');
    }
    expect(
      infractores,
      isEmpty,
      reason: 'Usa AppColors (y AppElevation para las sombras: `Colors.black` '
          'con alfa no es una sombra de marca, es suciedad sobre el fondo):\n'
          '${infractores.join("\n")}',
    );
  });

  test('los roles de AppText viven en un solo sitio', () {
    // Contraparte de la prohibición, y el caso que de verdad sostiene este
    // archivo: si `app_text.dart` desapareciera o se vaciara, todos los casos
    // de arriba pasarían sin que exista escala alguna.
    final escala = File('lib/ui/core/theme/app_text.dart').readAsStringSync();
    for (final rol in [
      'display',
      'title',
      'subtitle',
      'body',
      'caption',
      'cta',
      'money',
      'moneySm',
      'label',
    ]) {
      expect(
        escala.contains('TextStyle $rol ='),
        isTrue,
        reason: 'Falta el rol `$rol` en AppText.',
      );
    }
  });

  test('los niveles de AppElevation viven en un solo sitio', () {
    // Misma contraparte para la elevación: sin ella, borrar `app_elevation.dart`
    // devolvería las tarjetas al borde gris de 1 px sin que nada fallara.
    final elevacion =
        File('lib/ui/core/theme/app_elevation.dart').readAsStringSync();
    for (final nivel in ['carta', 'agrupador', 'flotante', 'anclada']) {
      expect(
        elevacion.contains('BoxShadow> $nivel ='),
        isTrue,
        reason: 'Falta el nivel `$nivel` en AppElevation.',
      );
    }
  });
}

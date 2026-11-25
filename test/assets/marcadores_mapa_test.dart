import 'dart:io';
import 'dart:typed_data';

import 'package:app_conductor/ui/core/widgets/map_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ancho y alto de un PNG, leídos de su cabecera IHDR (bytes 16 a 24).
///
/// Se lee la cabecera y no se decodifica la imagen, que es la misma regla que
/// sigue el backend al validar lo que se sube: decodificar para preguntar cuánto
/// mide es la forma clásica de tumbar un proceso con un archivo pequeño. Aquí,
/// de paso, evita depender del motor gráfico en un test que solo mira bytes.
({int ancho, int alto}) _dimensionesPng(File archivo) {
  final bytes = archivo.readAsBytesSync();
  final vista = ByteData.sublistView(Uint8List.fromList(bytes));
  return (ancho: vista.getUint32(16), alto: vista.getUint32(20));
}

/// Presupuesto propio de los marcadores del mapa, mucho más bajo que el general.
///
/// El motivo no es el peso del APK, que a este tamaño da igual: es que un
/// marcador se **redimensiona en cada fotograma** mientras el conductor se
/// mueve, y una imagen tres veces más grande de lo que se pinta cuesta ese
/// escalado sesenta veces por segundo en el teléfono más lento del parque, que
/// es justo el que va a tener esta pantalla abierta veinte minutos.
///
/// El tope general de 300 KB es el techo de una ilustración que se abre a
/// pantalla completa; aquí se pinta un dibujo de 44 dp.
void main() {
  const topeBytes = 40 * 1024;

  /// A cuánto de su tamaño lógico puede llegar el asset. Tres es la densidad
  /// máxima que se sirve hoy; empaquetar a 512 px «por si acaso» es el gasto
  /// que este test existe para impedir.
  const factorMaximo = 3;

  final marcadores = [marcadorRecogida, marcadorEntrega, marcadorConductor];

  test('hay marcadores que revisar', () {
    // Un presupuesto que no vigila nada es peor que no tenerlo: parece que sí.
    expect(marcadores, isNotEmpty);
  });

  test('los tres assets existen', () {
    for (final m in marcadores) {
      expect(File(m.asset).existsSync(), isTrue,
          reason: 'falta el asset ${m.asset}');
    }
  });

  test('ningún marcador pasa de su presupuesto de peso', () {
    final excedidos = <String>[];
    for (final m in marcadores) {
      final bytes = File(m.asset).lengthSync();
      if (bytes > topeBytes) {
        excedidos.add('${m.asset}: ${(bytes / 1024).round()} KB '
            '(tope ${topeBytes ~/ 1024} KB)');
      }
    }
    expect(excedidos, isEmpty, reason: excedidos.join('\n'));
  });

  test('ningún marcador tiene más resolución de la que se pinta', () {
    final excedidos = <String>[];
    for (final m in marcadores) {
      final imagen = _dimensionesPng(File(m.asset));
      final maximoAlto = m.alto * factorMaximo;
      final maximoAncho = m.ancho * factorMaximo;
      if (imagen.alto > maximoAlto || imagen.ancho > maximoAncho) {
        excedidos.add('${m.asset}: ${imagen.ancho}×${imagen.alto} px '
            'para ${m.ancho.round()}×${m.alto.round()} dp '
            '(máximo ${maximoAncho.round()}×${maximoAlto.round()})');
      }
    }
    expect(excedidos, isEmpty, reason: excedidos.join('\n'));
  });

  test('el aspecto declarado es el del archivo', () {
    // El aspecto decide el ancho del marcador, y si se desvía del archivo la
    // ilustración se estira sin que nada falle: se ve como un pin más gordo.
    for (final m in marcadores) {
      final imagen = _dimensionesPng(File(m.asset));
      expect(imagen.ancho / imagen.alto, closeTo(m.aspecto, 0.01),
          reason: '${m.asset} declara ${m.aspecto} y mide '
              '${imagen.ancho / imagen.alto}');
    }
  });
}

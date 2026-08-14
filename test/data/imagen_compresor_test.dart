import 'dart:io';
import 'dart:math' as math;

import 'package:app_conductor/data/services/imagen_compresor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// La evidencia de entrega se sube desde la calle, con datos móviles y con el
/// cliente delante. Comprimir antes de subir es lo que convierte una espera de
/// veinte segundos en una de cinco.
///
/// Lo que estos tests fijan es que **comprimir nunca puede impedir una entrega**:
/// cada camino de fallo devuelve el archivo original en vez de lanzar.
void main() {
  // `compute` necesita el binding para el isolate de fondo.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  const compresor = ImagenCompresor();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('evidencia_test');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// JPEG parecido a una foto: degradados suaves con detalle encima.
  ///
  /// A calidad 95 pesa de sobra, y al bajar la calidad se comprime como se
  /// comprime una foto de cámara. Una imagen de color plano cabría en cualquier
  /// tope y el test no probaría nada; y el ruido puro tampoco vale (ver el test
  /// que lo usa a propósito).
  File jpegComoFoto(String nombre, {int lado = 1280}) {
    final aleatorio = math.Random(7);
    final imagen = img.Image(width: lado, height: lado);
    for (var y = 0; y < lado; y++) {
      for (var x = 0; x < lado; x++) {
        final onda = (math.sin(x / 37) * math.cos(y / 53) * 60).round();
        imagen.setPixelRgb(
          x,
          y,
          (120 + onda + aleatorio.nextInt(24)).clamp(0, 255),
          (90 + onda + aleatorio.nextInt(24)).clamp(0, 255),
          (70 + onda + aleatorio.nextInt(24)).clamp(0, 255),
        );
      }
    }
    return File('${dir.path}/$nombre')
      ..writeAsBytesSync(img.encodeJpg(imagen, quality: 95));
  }

  /// Ruido uniforme: el caso patológico. No baja del tope ni a calidad 35.
  File jpegDeRuidoPuro(String nombre, {int lado = 1280}) {
    final aleatorio = math.Random(11);
    final imagen = img.Image(width: lado, height: lado);
    for (final pixel in imagen) {
      pixel.setRgb(
        aleatorio.nextInt(256),
        aleatorio.nextInt(256),
        aleatorio.nextInt(256),
      );
    }
    return File('${dir.path}/$nombre')
      ..writeAsBytesSync(img.encodeJpg(imagen, quality: 95));
  }

  test(
    'un archivo que ya cabe se devuelve intacto, en su misma ruta',
    () async {
      final pequeno = File('${dir.path}/pequena.jpg')
        ..writeAsBytesSync(
          img.encodeJpg(img.Image(width: 40, height: 40), quality: 80),
        );
      final antes = pequeno.lengthSync();

      final resultado = await compresor.aTope(pequeno);

      // Misma ruta: no se recodifica por gusto ni se deja un archivo de sobra.
      expect(resultado.path, pequeno.path);
      expect(resultado.lengthSync(), antes);
    },
  );

  test('una foto por encima del tope baja del tope', () async {
    final grande = jpegComoFoto('grande.jpg');
    final antes = grande.lengthSync();
    expect(
      antes,
      greaterThan(300 * 1024),
      reason: 'el fixture tiene que pesar',
    );

    final resultado = await compresor.aTope(grande);

    expect(resultado.path, isNot(grande.path));
    expect(resultado.lengthSync(), lessThanOrEqualTo(300 * 1024));
    // Y el original sigue ahí: nadie borra la foto del conductor.
    expect(grande.existsSync(), isTrue);
  });

  test(
    'lo que no cabe ni al piso de calidad se envía lo más pequeño posible',
    () async {
      // El tope **no es una promesa**: por eso existe el piso de calidad. Con ruido
      // uniforme —el peor caso para un JPEG— ni la calidad 35 baja de 1 MB, y la
      // respuesta correcta es enviar la más pequeña que se consiguió, no degradarla
      // hasta cumplir un número ni fallar la entrega.
      final ruido = jpegDeRuidoPuro('ruido.jpg');
      final antes = ruido.lengthSync();

      final resultado = await compresor.aTope(ruido);

      expect(resultado.lengthSync(), lessThan(antes));
      expect(resultado.lengthSync(), greaterThan(300 * 1024));
    },
  );

  test('con un tope imposible no lanza y algo mejora', () async {
    final grande = jpegComoFoto('imposible.jpg');
    final antes = grande.lengthSync();

    final resultado = await compresor.aTope(grande, topeBytes: 1024);

    expect(resultado.lengthSync(), lessThan(antes));
  });

  test('el piso de calidad se prueba de verdad', () async {
    // La escala baja de 10 en 10 desde 70; con `q -= 10` la última era la 40 y la
    // calidad 35 no se llegaba a codificar nunca — el piso prometido no era el
    // piso real. Se comprueba comparando contra la 40 hecha a mano: lo que sale
    // del compresor con un tope inalcanzable tiene que ser **más pequeño**.
    final grande = jpegComoFoto('piso.jpg');
    final decodificada = img.decodeImage(grande.readAsBytesSync())!;
    final a40 = img.encodeJpg(decodificada, quality: 40).length;

    final resultado = await compresor.aTope(grande, topeBytes: 1024);

    expect(resultado.lengthSync(), lessThan(a40));
  });

  test('un archivo ilegible devuelve el original', () async {
    final basura = File('${dir.path}/no-es-imagen.jpg')
      ..writeAsBytesSync(List<int>.filled(400 * 1024, 7));

    final resultado = await compresor.aTope(basura);

    expect(resultado.path, basura.path);
  });

  test('un archivo que no existe devuelve el original', () async {
    // Una entrega no se bloquea por no poder comprimir. Nunca.
    final fantasma = File('${dir.path}/no-existe.jpg');

    final resultado = await compresor.aTope(fantasma);

    expect(resultado.path, fantasma.path);
  });
}

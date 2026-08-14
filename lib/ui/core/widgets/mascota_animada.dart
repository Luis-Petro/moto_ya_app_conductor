import 'package:flutter/material.dart';

/// Los momentos en los que la mascota tiene algo que decir.
///
/// Son los tres estados de espera de la negociación —donde el cliente mira una
/// pantalla sin saber qué pasa— más el aviso de versión nueva. Fuera de ahí, la
/// mascota es decoración y no hace falta.
enum PoseMascota {
  /// Buscando conductor: sentada, pensando. Flota, con calma.
  espera('assets/images/mascota_espera.png', 'Buscando un conductor'),

  /// Llegó una propuesta: pulgar arriba. Entra con rebote.
  celebra('assets/images/mascota_celebra.png', 'Un conductor te respondió'),

  /// Nadie tomó el pedido: de pie junto a la moto, sin ánimo.
  triste('assets/images/mascota_triste.png', 'Ningún conductor disponible'),

  /// Hay versión nueva: con el teléfono en la mano. Quieta.
  actualizar('assets/images/mascota_actualizar.png', 'Hay una versión nueva'),

  /// Saludando. La cara amable de la marca cuando no pasa nada concreto.
  saludo('assets/images/mascota_saludo.png', 'Zumbeo');

  const PoseMascota(this.asset, this.descripcion);

  final String asset;

  /// Lo que la pose significa, para quien no la ve. Una mascota sin texto
  /// alternativo es ruido en un lector de pantalla.
  final String descripcion;
}

/// La mascota de marca, animada según el estado.
///
/// **Por qué son PNG y no Lottie.** La animación de personaje de verdad exige
/// producir los JSON, que no salen de una ilustración: habría que encargarlos, y
/// esto se quedaría esperando a un trabajo de diseño. Lo que se pierde es
/// fluidez —no hay parpadeo ni deformación—; lo que se gana es que funciona hoy,
/// sin dependencias nuevas, sin peso extra en el APK y sin red. Si algún día
/// llegan los Lottie, este widget es el único sitio que cambia.
///
/// Cada pose tiene su gesto, y el gesto es el que dice qué está pasando antes de
/// que nadie lea el texto:
///
/// | Pose | Animación |
/// |---|---|
/// | espera | flota en vertical, 1,6 s, ida y vuelta |
/// | celebra | entra con rebote (`elasticOut`, 600 ms) |
/// | triste | micro-balanceo de 2°, lento |
/// | actualizar / saludo | quietas |
class MascotaAnimada extends StatefulWidget {
  const MascotaAnimada({super.key, required this.pose, this.alto = 140});

  final PoseMascota pose;
  final double alto;

  @override
  State<MascotaAnimada> createState() => _MascotaAnimadaState();
}

class _MascotaAnimadaState extends State<MascotaAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  /// Si esta pose tiene un movimiento continuo (las otras se pintan quietas).
  bool get _seMueve =>
      widget.pose == PoseMascota.espera || widget.pose == PoseMascota.triste;

  @override
  void didUpdateWidget(covariant MascotaAnimada oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pose != oldWidget.pose) _sincronizarMovimiento();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sincronizarMovimiento();
  }

  /// Arranca o para el bucle según la pose y según lo que quiera el sistema.
  ///
  /// Con las animaciones del teléfono apagadas no se anima nada: quien las apagó
  /// lo hizo por algo, normalmente porque el teléfono no da para más, y ese es
  /// justo el público de esta app.
  void _sincronizarMovimiento() {
    final permitidas = !MediaQuery.disableAnimationsOf(context);
    if (_seMueve && permitidas) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.disableAnimationsOf(context);
    final imagen = Image.asset(
      widget.pose.asset,
      height: widget.alto,
      fit: BoxFit.contain,
      semanticLabel: widget.pose.descripcion,
      // La pose es la que cambia; la caja no puede saltar mientras carga.
      gaplessPlayback: true,
    );

    Widget contenido = imagen;
    if (!quieto && _seMueve) {
      contenido = AnimatedBuilder(
        animation: _c,
        builder: (_, hijo) {
          final t = Curves.easeInOut.transform(_c.value);
          return widget.pose == PoseMascota.espera
              // Flotar: seis píxeles arriba y abajo. Más se lee como un fallo.
              ? Transform.translate(offset: Offset(0, -6 * t), child: hijo)
              // Desánimo: un balanceo de dos grados, apenas perceptible, que es
              // lo que lo hace leerse como desgana y no como un tic.
              : Transform.rotate(angle: (t - 0.5) * 0.035, child: hijo);
        },
        child: imagen,
      );
    }

    // La pose se sustituye con una transición, nunca de un frame a otro: el
    // salto seco hace que parezca que la pantalla se rompió, justo en el momento
    // en que el cliente está pendiente de si su pedido salió.
    return AnimatedSwitcher(
      duration: quieto ? Duration.zero : const Duration(milliseconds: 600),
      transitionBuilder: (hijo, animacion) {
        // El rebote va **solo en la escala**. `elasticOut` sobrepasa el 1.0 —esa
        // es la gracia del rebote— y `FadeTransition` exige una opacidad dentro
        // de [0,1]: pasárselo directamente revienta en tiempo de ejecución.
        final escala = CurvedAnimation(
          parent: animacion,
          curve: widget.pose == PoseMascota.celebra
              ? Curves.elasticOut
              : Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: animacion, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(escala),
            child: hijo,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(widget.pose), child: contenido),
    );
  }
}

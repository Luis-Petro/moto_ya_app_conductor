import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/municipio_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../di/locator.dart';
import '../../../domain/models/catalogo_motos.dart';
import '../../../domain/models/municipio.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../router.dart';
import 'alta_conductor_view_model.dart';

/// Alta del perfil de conductor (vehículo, placa, licencia opcional) + documentos.
class AltaConductorScreen extends StatelessWidget {
  const AltaConductorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AltaConductorViewModel(
        locator<ConductorRepository>(),
        locator<LocationService>(),
        locator<MunicipioRepository>(),
        locator<UsuarioRepository>(),
      )..cargar(),
      child: const _AltaView(),
    );
  }
}

class _AltaView extends StatefulWidget {
  const _AltaView();

  @override
  State<_AltaView> createState() => _AltaViewState();
}

class _AltaViewState extends State<_AltaView> {
  final _licencia = TextEditingController();
  final _placa = TextEditingController();

  /// Marca y modelo escritos a mano, cuando la moto no está en la lista.
  final _marcaLibre = TextEditingController();
  final _modeloLibre = TextEditingController();

  String? _marca;
  String? _modelo;

  final _picker = ImagePicker();
  bool _saltoAplicado = false;

  /// Paso visible. El alta era una sola pantalla con scroll largo, y el scroll
  /// largo es donde se abandonan los formularios: no se ve el final, no se sabe
  /// cuánto falta y cada campo parece uno más de una lista sin fondo.
  final _paginas = PageController();
  int _paso = 0;
  static const int _pasos = 3;

  @override
  void dispose() {
    _licencia.dispose();
    _placa.dispose();
    _marcaLibre.dispose();
    _modeloLibre.dispose();
    _paginas.dispose();
    super.dispose();
  }

  // ── Moto ──

  /// La moto compuesta, o null si falta marca o modelo.
  String? get _vehiculo {
    final marca = _marca == kOtro ? _marcaLibre.text : _marca;
    final modelo = (_modelo == kOtro || _marca == kOtro)
        ? _modeloLibre.text
        : _modelo;
    return componerVehiculo(marca, modelo);
  }

  /// Con "Otra" en la marca no hay lista de modelos que ofrecer: el modelo pasa
  /// también a campo libre.
  bool get _modeloEsLibre => _marca == kOtro || _modelo == kOtro;

  void _elegirMarca(String? m) {
    setState(() {
      _marca = m;
      // Cambiar de marca invalida el modelo: una Boxer no es una Yamaha.
      _modelo = null;
      _modeloLibre.clear();
      if (m != kOtro) _marcaLibre.clear();
    });
  }

  bool _valido(AltaConductorViewModel vm) => _faltantes(vm).isEmpty;

  /// Qué le falta al conductor para poder enviar (se muestra bajo el botón).
  List<String> _faltantes(AltaConductorViewModel vm) => [
        if (_vehiculo == null) 'decirnos cuál es tu moto',
        if (_placa.text.trim().length < 5) 'la placa completa',
        if (!vm.tieneCedula) 'la foto de tu cédula',
      ];

  bool get _motoLista =>
      _vehiculo != null && _placa.text.trim().length >= 5;

  /// Hitos del alta: cuenta creada, datos de la moto y los cuatro documentos.
  /// El primero ya está cumplido al llegar aquí, así que el conductor nunca ve
  /// una barra en cero: arrancar con avance visible es lo que hace que la gente
  /// termine formularios largos.
  ///
  /// **La barra sigue midiendo datos, no pasos**, aunque ahora haya pasos: la
  /// pregunta del conductor es "¿cuánto me falta para que me habiliten?", y esa
  /// no la responde ir por la pantalla 2 de 3.
  static const int _totalHitos = 2 + AltaConductorViewModel.documentosRequeridos;

  int _completados(AltaConductorViewModel vm) =>
      1 + (_motoLista ? 1 : 0) + vm.documentosListos;

  // ── Navegación por pasos ──

  /// Si el paso actual está completo. Lo que bloquea "Continuar".
  bool _pasoValido(AltaConductorViewModel vm) => switch (_paso) {
        0 => _motoLista,
        // La cédula es lo mínimo para enviar; el resto se puede completar luego.
        1 => vm.tieneCedula,
        _ => _valido(vm),
      };

  void _siguiente() {
    if (_paso >= _pasos - 1) return;
    setState(() => _paso++);
    _paginas.animateToPage(_paso,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// Vuelve un paso. En el primero, sale de la pantalla.
  ///
  /// Es lo que hacen la flecha del encabezado y el gesto de atrás del sistema:
  /// salirse del alta entera por darle atrás una vez de más es la forma más
  /// tonta de perder un conductor.
  void _atras() {
    if (_paso == 0) {
      if (context.canPop()) context.pop();
      return;
    }
    setState(() => _paso--);
    _paginas.animateToPage(_paso,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _guardar(AltaConductorViewModel vm) async {
    if (!_valido(vm)) return;
    final ok = await vm.guardar(
      licencia: _licencia.text.trim(),
      vehiculo: _vehiculo!,
      placa: _placa.text.trim().toUpperCase(),
    );
    if (!mounted) return;
    if (ok) {
      context.go(Rutas.inicio);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'No pudimos guardar tu perfil')),
      );
      if (vm.sesionInvalida) {
        // JWT viejo sin rol CONDUCTOR: cerrar sesión aquí mismo; el router
        // redirige al login y el nuevo JWT ya llega promovido.
        await locator<AuthRepository>().sesionExpirada();
        locator<ConductorRepository>().limpiar();
      }
    }
  }

  /// Foto de la cédula: primero una guía sencilla de cómo tomarla y luego la
  /// cámara (o galería). Pensado para personas poco acostumbradas al celular.
  Future<void> _tomarCedula(AltaConductorViewModel vm) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _GuiaCedulaSheet(),
    );
    if (source == null) return;
    await _capturar(source, vm.elegirCedula);
  }

  /// Papeles de la moto (SOAT / tarjeta de propiedad): elegir cámara o galería.
  Future<void> _tomarPapeles(AltaConductorViewModel vm) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => const _OrigenFotoSheet(
        titulo: 'SOAT o tarjeta de propiedad',
        mensaje: 'Puedes subir uno solo o los dos juntos en una misma foto.',
      ),
    );
    if (source == null) return;
    await _capturar(source, vm.elegirPapelesMoto);
  }

  /// Selfie de verificación: se abre la cámara frontal directamente, que es lo
  /// que la gente espera al oír "selfie".
  Future<void> _tomarSelfie(AltaConductorViewModel vm) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => const _OrigenFotoSheet(
        titulo: 'Selfie tuya',
        mensaje: 'De frente, con buena luz y sin gafas oscuras ni casco. Debe '
            'parecerse a la foto de tu cédula.',
      ),
    );
    if (source == null) return;
    await _capturar(source, vm.elegirSelfie,
        camara: CameraDevice.front);
  }

  /// Foto de la moto con la placa visible: es como el admin comprueba que la
  /// placa registrada es la de la moto real.
  Future<void> _tomarFotoMoto(AltaConductorViewModel vm) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => const _OrigenFotoSheet(
        titulo: 'Foto de tu moto',
        mensaje: 'Tómala de lado o desde atrás, a un par de pasos, de modo que '
            'la placa se lea sin esfuerzo.',
      ),
    );
    if (source == null) return;
    await _capturar(source, vm.elegirFotoMoto);
  }

  Future<void> _capturar(ImageSource source, void Function(File) onElegido,
      {CameraDevice camara = CameraDevice.rear}) async {
    // Calidad/tamaño altos para que los datos del documento se lean bien.
    final XFile? foto = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      preferredCameraDevice: camara,
    );
    if (foto == null) return;
    onElegido(File(foto.path));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AltaConductorViewModel>();

    // Si el perfil ya está completo, saltar directo a Inicio.
    if (!vm.cargando && vm.perfilCompleto && !_saltoAplicado) {
      _saltoAplicado = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Rutas.inicio);
      });
    }

    if (vm.cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Completa tu perfil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      // El gesto de atrás retrocede de paso; solo sale desde el primero.
      canPop: _paso == 0,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _atras();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Completa tu perfil'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: _paso == 0 ? 'Salir' : 'Paso anterior',
            onPressed: _atras,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paso ${_paso + 1} de $_pasos · ${_tituloPaso(_paso)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkMuted,
                            letterSpacing: 0.3)),
                    const SizedBox(height: AppSpacing.sm),
                    _ProgresoAlta(hechos: _completados(vm), total: _totalHitos),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _paginas,
                  // Solo se avanza con el botón: deslizar se saltaría la
                  // validación del paso sin que nadie lo note.
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _PasoMoto(
                      vm: vm,
                      marca: _marca,
                      modelo: _modelo,
                      marcaLibre: _marcaLibre,
                      modeloLibre: _modeloLibre,
                      modeloEsLibre: _modeloEsLibre,
                      placa: _placa,
                      licencia: _licencia,
                      onMarca: _elegirMarca,
                      onModelo: (m) => setState(() => _modelo = m),
                      onCambio: () => setState(() {}),
                    ),
                    _PasoDocumentos(
                      vm: vm,
                      onCedula: () => _tomarCedula(vm),
                      onPapeles: () => _tomarPapeles(vm),
                      onSelfie: () => _tomarSelfie(vm),
                      onFotoMoto: () => _tomarFotoMoto(vm),
                    ),
                    _PasoRevision(
                      vm: vm,
                      motoLista: _motoLista,
                      vehiculo: _vehiculo,
                      placa: _placa.text.trim().toUpperCase(),
                      onIrAPaso: (p) {
                        setState(() => _paso = p);
                        _paginas.jumpToPage(p);
                      },
                    ),
                  ],
                ),
              ),
              _PieDelPaso(
                vm: vm,
                esUltimo: _paso == _pasos - 1,
                habilitado: _pasoValido(vm),
                faltaEnEstePaso: _faltaEnEstePaso(vm),
                onContinuar: _siguiente,
                onEnviar: () => _guardar(vm),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _tituloPaso(int paso) => switch (paso) {
        0 => 'Tu moto',
        1 => 'Tus documentos',
        _ => 'Revisar y enviar',
      };

  /// Qué falta **de este paso**, no del alta entera. Decirle a alguien en el
  /// paso de la moto que le falta la cédula es ruido: todavía no ha llegado.
  String? _faltaEnEstePaso(AltaConductorViewModel vm) {
    if (_paso == 0) {
      if (_vehiculo == null) return 'Elige la marca y el modelo de tu moto.';
      if (_placa.text.trim().length < 5) return 'Escribe la placa completa.';
      return null;
    }
    if (_paso == 1 && !vm.tieneCedula) {
      return 'La foto de tu cédula es la única obligatoria para enviar.';
    }
    if (_paso == _pasos - 1) {
      final faltan = _faltantes(vm);
      if (faltan.isNotEmpty) return 'Te falta: ${faltan.join(', ')}.';
      if (vm.documentosFaltantes.isNotEmpty) {
        // Puede enviar, pero conviene que sepa desde ya que sin estas fotos el
        // admin no lo habilitará: enterarse al segundo día de espera es la peor
        // forma de saberlo.
        return 'Puedes enviar ya. Para habilitarte falta: '
            '${vm.documentosFaltantes.join(', ')}. Súbelo desde tu perfil '
            'cuando lo tengas.';
      }
    }
    return null;
  }
}

/// Paso 1 · la moto: marca, modelo, placa, municipio y licencia.
class _PasoMoto extends StatelessWidget {
  const _PasoMoto({
    required this.vm,
    required this.marca,
    required this.modelo,
    required this.marcaLibre,
    required this.modeloLibre,
    required this.modeloEsLibre,
    required this.placa,
    required this.licencia,
    required this.onMarca,
    required this.onModelo,
    required this.onCambio,
  });

  final AltaConductorViewModel vm;
  final String? marca;
  final String? modelo;
  final TextEditingController marcaLibre;
  final TextEditingController modeloLibre;
  final bool modeloEsLibre;
  final TextEditingController placa;
  final TextEditingController licencia;
  final ValueChanged<String?> onMarca;
  final ValueChanged<String?> onModelo;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final modelos = modelosDe(marca);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const Text('Cuéntanos de tu moto',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.xs),
        const Text(
            'Con estos datos y la foto de tu cédula quedas en revisión. Te avisamos apenas puedas empezar a trabajar.',
            style: TextStyle(color: AppColors.inkMuted)),
        const SizedBox(height: AppSpacing.xl),
        const _Label('Marca'),
        DropdownButtonFormField<String>(
          value: marca,
          isExpanded: true,
          items: [
            for (final m in marcasMoto)
              DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: onMarca,
          decoration: const InputDecoration(
            hintText: 'Elige la marca',
            prefixIcon: Icon(Icons.two_wheeler_rounded),
          ),
        ),
        if (marca == kOtro) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: marcaLibre,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => onCambio(),
            decoration: const InputDecoration(hintText: '¿Qué marca es?'),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const _Label('Modelo'),
        DropdownButtonFormField<String>(
          value: modelo,
          isExpanded: true,
          items: [
            for (final m in modelos) DropdownMenuItem(value: m, child: Text(m)),
          ],
          // Sin marca no hay modelos que ofrecer: un desplegable vacío que se
          // abre y no muestra nada parece la app rota.
          onChanged: modelos.isEmpty ? null : onModelo,
          decoration: InputDecoration(
            hintText: marca == null ? 'Elige primero la marca' : 'Elige el modelo',
            prefixIcon: const Icon(Icons.confirmation_number_outlined),
          ),
        ),
        if (modeloEsLibre) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: modeloLibre,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => onCambio(),
            decoration: const InputDecoration(hintText: '¿Qué modelo es?'),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const _Label('Placa'),
        TextField(
          controller: placa,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => onCambio(),
          decoration: const InputDecoration(
            hintText: 'ABC-12D',
            prefixIcon: Icon(Icons.pin_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _Label('¿En qué municipio trabajas?'),
        DropdownButtonFormField<Municipio>(
          value: vm.municipioElegido,
          items: vm.municipios
              .map((m) => DropdownMenuItem(value: m, child: Text(m.etiqueta)))
              .toList(),
          onChanged: vm.elegirMunicipio,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _Label('Número de licencia (opcional)'),
        TextField(
          controller: licencia,
          onChanged: (_) => onCambio(),
          decoration: const InputDecoration(
            hintText: 'Ej. 123456789',
            prefixIcon: Icon(Icons.badge_outlined),
            helperText: 'Por ahora no es obligatoria. Puedes agregarla después.',
            helperMaxLines: 2,
          ),
        ),
      ],
    );
  }
}

/// Paso 2 · las cuatro fotos.
class _PasoDocumentos extends StatelessWidget {
  const _PasoDocumentos({
    required this.vm,
    required this.onCedula,
    required this.onPapeles,
    required this.onSelfie,
    required this.onFotoMoto,
  });

  final AltaConductorViewModel vm;
  final VoidCallback onCedula;
  final VoidCallback onPapeles;
  final VoidCallback onSelfie;
  final VoidCallback onFotoMoto;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const Text('Tus documentos',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.xs),
        const Text(
            'Son cuatro fotos. Con la cédula ya puedes enviar tu solicitud, '
            'pero el administrador necesita las cuatro para habilitarte.',
            style: TextStyle(color: AppColors.inkMuted)),
        const SizedBox(height: AppSpacing.lg),
        _DocCard(
          icon: Icons.badge_outlined,
          titulo: 'Foto de tu cédula',
          subtitulo: 'Solo el lado de adelante (donde está tu foto)',
          etiqueta: 'Necesaria para enviar',
          etiquetaColor: AppColors.primary,
          archivo: vm.cedula,
          accion: 'Tomar foto',
          onElegir: onCedula,
        ),
        const SizedBox(height: AppSpacing.md),
        _DocCard(
          icon: Icons.description_outlined,
          titulo: 'Tarjeta de propiedad de la moto',
          subtitulo: 'La tarjeta donde aparece la placa y tu nombre. Puedes '
              'incluir el SOAT en la misma foto.',
          etiqueta: 'Para habilitarte',
          etiquetaColor: AppColors.accent,
          archivo: vm.papelesMoto,
          accion: 'Subir',
          onElegir: onPapeles,
        ),
        const SizedBox(height: AppSpacing.md),
        _DocCard(
          icon: Icons.face_outlined,
          titulo: 'Selfie tuya',
          subtitulo: 'Tu cara, de frente y con buena luz. Sirve para '
              'confirmar que la cédula es tuya.',
          etiqueta: 'Para habilitarte',
          etiquetaColor: AppColors.accent,
          archivo: vm.selfie,
          accion: 'Tomar selfie',
          onElegir: onSelfie,
        ),
        const SizedBox(height: AppSpacing.md),
        _DocCard(
          icon: Icons.two_wheeler_outlined,
          titulo: 'Foto de tu moto',
          subtitulo: 'De lado o desde atrás, con la placa que se pueda leer.',
          etiqueta: 'Para habilitarte',
          etiquetaColor: AppColors.accent,
          archivo: vm.fotoMoto,
          accion: 'Tomar foto',
          onElegir: onFotoMoto,
        ),
      ],
    );
  }
}

/// Paso 3 · lo que se va a enviar, con la vuelta a cada paso a un toque.
class _PasoRevision extends StatelessWidget {
  const _PasoRevision({
    required this.vm,
    required this.motoLista,
    required this.vehiculo,
    required this.placa,
    required this.onIrAPaso,
  });

  final AltaConductorViewModel vm;
  final bool motoLista;
  final String? vehiculo;
  final String placa;
  final ValueChanged<int> onIrAPaso;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const Text('Revisa y envía',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.xs),
        const Text(
            'Esto es lo que verá el administrador. Puedes volver a cualquier '
            'paso para cambiarlo.',
            style: TextStyle(color: AppColors.inkMuted)),
        const SizedBox(height: AppSpacing.lg),
        MotoCard(
          onTap: () => onIrAPaso(0),
          child: Row(
            children: [
              const Icon(Icons.two_wheeler_rounded, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehiculo ?? 'Sin definir',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(placa.isEmpty ? 'Sin placa' : 'Placa $placa',
                        style: const TextStyle(
                            color: AppColors.inkMuted, fontSize: 12.5)),
                    if (vm.municipioElegido != null)
                      Text(vm.municipioElegido!.etiqueta,
                          style: const TextStyle(
                              color: AppColors.inkMuted, fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined,
                  size: 18, color: AppColors.inkMuted),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GestureDetector(
          onTap: () => onIrAPaso(1),
          child: _Checklist(vm: vm, motoLista: motoLista),
        ),
        const SizedBox(height: AppSpacing.md),
        const _AvisoRevision(),
      ],
    );
  }
}

/// Pie fijo del paso: el botón que avanza o envía, y el motivo si no se puede.
///
/// Va fuera del `PageView` a propósito: un botón que hay que ir a buscar al
/// final de un scroll es la mitad del problema que este cambio venía a quitar.
class _PieDelPaso extends StatelessWidget {
  const _PieDelPaso({
    required this.vm,
    required this.esUltimo,
    required this.habilitado,
    required this.faltaEnEstePaso,
    required this.onContinuar,
    required this.onEnviar,
  });

  final AltaConductorViewModel vm;
  final bool esUltimo;
  final bool habilitado;
  final String? faltaEnEstePaso;
  final VoidCallback onContinuar;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: esUltimo
                ? (vm.guardando ? 'Enviando tus datos…' : 'Enviar para revisión')
                : 'Continuar',
            icon: esUltimo ? null : Icons.arrow_forward_rounded,
            loading: esUltimo && vm.guardando,
            onPressed:
                habilitado ? (esUltimo ? onEnviar : onContinuar) : null,
          ),
          if (faltaEnEstePaso != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              faltaEnEstePaso!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// Avance del alta contando lo que el conductor ya hizo. La cuenta creada es
/// un hito real y ya cumplido: reconocerlo evita presentar el trámite como
/// "0 de 3" justo cuando es más fácil abandonarlo.
class _ProgresoAlta extends StatelessWidget {
  const _ProgresoAlta({required this.hechos, required this.total});

  final int hechos;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraccion = (hechos / total).clamp(0.0, 1.0);
    final completo = hechos >= total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                completo
                    ? '¡Listo! Ya puedes enviar tu solicitud'
                    : 'Ya llevas $hechos de $total',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            Text('${(fraccion * 100).round()}%',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: fraccion),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (_, valor, __) => LinearProgressIndicator(
              value: valor,
              minHeight: 8,
              backgroundColor: AppColors.line,
              valueColor: AlwaysStoppedAnimation<Color>(
                  completo ? AppColors.success : AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Qué falta y qué ya está, en positivo y junto al botón de envío.
class _Checklist extends StatelessWidget {
  const _Checklist({required this.vm, required this.motoLista});

  final AltaConductorViewModel vm;
  final bool motoLista;

  @override
  Widget build(BuildContext context) {
    final c = vm.conductor;
    return Column(
      children: [
        const _ItemChecklist(hecho: true, texto: 'Cuenta creada'),
        _ItemChecklist(hecho: motoLista, texto: 'Datos de tu moto y placa'),
        _ItemChecklist(
            hecho: vm.cedula != null || (c?.tieneCedula ?? false),
            texto: 'Foto de tu cédula'),
        _ItemChecklist(
            hecho: vm.papelesMoto != null || (c?.tieneTarjetaPropiedad ?? false),
            texto: 'Tarjeta de propiedad'),
        _ItemChecklist(
            hecho: vm.selfie != null || (c?.tieneSelfie ?? false),
            texto: 'Selfie tuya'),
        _ItemChecklist(
            hecho: vm.fotoMoto != null || (c?.tieneFotoMoto ?? false),
            texto: 'Foto de tu moto con la placa'),
      ],
    );
  }
}

class _ItemChecklist extends StatelessWidget {
  const _ItemChecklist({required this.hecho, required this.texto});

  final bool hecho;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(hecho ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 20, color: hecho ? AppColors.success : AppColors.line),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 14,
                color: hecho ? AppColors.ink : AppColors.inkMuted,
                fontWeight: hecho ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.inkMuted,
              letterSpacing: 0.4)),
    );
  }
}

/// Tarjeta para adjuntar un documento. Toda la tarjeta es tocable (área táctil
/// grande) y al tener foto muestra la miniatura con opción de repetirla.
class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.etiqueta,
    required this.etiquetaColor,
    required this.archivo,
    required this.accion,
    required this.onElegir,
  });

  final IconData icon;
  final String titulo;
  final String subtitulo;
  final String etiqueta;
  final Color etiquetaColor;
  final File? archivo;
  final String accion;
  final VoidCallback onElegir;

  @override
  Widget build(BuildContext context) {
    final adjuntado = archivo != null;
    return MotoCard(
      onTap: onElegir,
      borderColor: adjuntado ? AppColors.success : null,
      child: Row(
        children: [
          if (adjuntado)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Image.file(archivo!,
                  width: 56, height: 56, fit: BoxFit.cover),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitulo,
                    style: const TextStyle(
                        color: AppColors.inkMuted, fontSize: 12.5)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (adjuntado) ...[
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 16),
                      const SizedBox(width: 4),
                      const Text('Foto lista',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ] else
                      Text(etiqueta,
                          style: TextStyle(
                              color: etiquetaColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: onElegir,
            child: Text(adjuntado ? 'Repetir' : accion),
          ),
        ],
      ),
    );
  }
}

/// Guía paso a paso para la foto de la cédula, en lenguaje sencillo.
/// Devuelve la fuente elegida (cámara o galería) o null si cancela.
class _GuiaCedulaSheet extends StatelessWidget {
  const _GuiaCedulaSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Foto de tu cédula',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            const Text(
                'Solo el lado de adelante, donde está tu foto. Sigue estos pasos:',
                style: TextStyle(color: AppColors.inkMuted)),
            const SizedBox(height: AppSpacing.lg),
            const _PasoGuia(
              numero: '1',
              icon: Icons.table_bar_outlined,
              texto: 'Pon la cédula sobre una mesa o superficie plana.',
            ),
            const _PasoGuia(
              numero: '2',
              icon: Icons.wb_sunny_outlined,
              texto: 'Busca buena luz, sin sombras ni reflejos encima.',
            ),
            const _PasoGuia(
              numero: '3',
              icon: Icons.zoom_in_rounded,
              texto:
                  'Acerca el celular hasta que los nombres y números se lean claros.',
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Abrir la cámara',
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: const Text('Ya tengo la foto en mi celular'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasoGuia extends StatelessWidget {
  const _PasoGuia({
    required this.numero,
    required this.icon,
    required this.texto,
  });

  final String numero;
  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text('$numero. $texto',
                style: const TextStyle(fontSize: 14.5, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

/// Selector simple de origen de la foto (cámara o galería) para documentos
/// opcionales.
class _OrigenFotoSheet extends StatelessWidget {
  const _OrigenFotoSheet({required this.titulo, required this.mensaje});

  final String titulo;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            Text(mensaje, style: const TextStyle(color: AppColors.inkMuted)),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Tomar una foto',
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: const Text('Elegir de la galería'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso de que la cuenta quedará en revisión tras enviar los documentos.
class _AvisoRevision extends StatelessWidget {
  const _AvisoRevision();

  @override
  Widget build(BuildContext context) {
    return MotoCard(
      color: AppColors.primarySurface,
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              'Revisaremos tus documentos y habilitaremos tu cuenta. Te avisaremos cuando puedas empezar a recibir pedidos.',
              style: TextStyle(color: AppColors.ink, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

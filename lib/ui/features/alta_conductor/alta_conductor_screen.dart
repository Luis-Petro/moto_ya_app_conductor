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
import '../../../data/services/vehiculo_service.dart';
import '../../../di/locator.dart';
import '../../../domain/models/catalogo_vehiculos.dart';
import '../../../domain/models/municipio.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/encabezado.dart';
import '../../core/widgets/imagen_de_vehiculo.dart';
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
        locator<VehiculoService>(),
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

  /// Marca y modelo escritos a mano, cuando el vehículo no está en el catálogo.
  final _marcaLibre = TextEditingController();
  final _modeloLibre = TextEditingController();

  /// Lo elegido en cada nivel: el id del catálogo, [_kOtro] para «Otro»/«Otra»,
  /// o `null` si todavía no se eligió nada.
  int? _tipoId;
  int? _marcaId;
  int? _modeloId;

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

  // ── El vehículo ──

  /// Sentinel de "Otro"/"Otra" en los tres desplegables. Los ids reales del
  /// catálogo son positivos, así que no puede chocar con ninguno.
  static const int _kOtro = -1;

  /// El tipo elegido del catálogo, o el que se está desplegando.
  TipoVehiculo? get _tipo => _tipoId == null || _tipoId == _kOtro
      ? null
      : _catalogo?.tipos.where((t) => t.id == _tipoId).firstOrNull;

  MarcaVehiculo? get _marcaElegida => _marcaId == null || _marcaId == _kOtro
      ? null
      : _tipo?.marcas.where((m) => m.id == _marcaId).firstOrNull;

  ModeloVehiculo? get _modeloElegido => _modeloId == null || _modeloId == _kOtro
      ? null
      : _marcaElegida?.modelos.where((m) => m.id == _modeloId).firstOrNull;

  /// La referencia que se manda al servidor, o `null` si el vehículo se escribió
  /// a mano. Es lo único que viaja cuando el conductor eligió de la lista: el
  /// texto lo compone el servidor.
  int? get _modeloVehiculoId => _modeloElegido?.id;

  /// El texto que se manda **solo cuando no hay referencia**.
  ///
  /// Antes esta app componía siempre `"$marca $modelo"` en el teléfono, y por eso
  /// el servidor nunca supo qué recibía: «Bajaj Boxer CT 100», «bajais boxer» y
  /// «BOXER 100» llegaban como si fueran datos.
  String? get _vehiculoLibre {
    if (_modeloVehiculoId != null) {
      return null;
    }
    final marca = _marcaId == _kOtro || _tipoId == _kOtro
        ? _marcaLibre.text.trim()
        : (_marcaElegida?.nombre ?? '');
    final modelo = _modeloEsLibre
        ? _modeloLibre.text.trim()
        : (_modeloElegido?.nombre ?? '');
    if (marca.isEmpty || modelo.isEmpty) {
      return null;
    }
    return '$marca $modelo';
  }

  /// Lo que se enseña en la pantalla de revisión. Con referencia se compone aquí
  /// **solo para verlo**: lo que se guarda lo compone el servidor.
  String? get _vehiculoParaVer {
    final m = _modeloElegido;
    if (m != null) {
      return '${_marcaElegida!.nombre} ${m.nombre}';
    }
    return _vehiculoLibre;
  }

  /// El vehículo está definido: por referencia o por texto completo.
  bool get _vehiculoDefinido =>
      _modeloVehiculoId != null || _vehiculoLibre != null;

  /// Con "Otra" en un nivel, los que dependen de él pasan también a texto libre:
  /// si la marca no está en el catálogo, sus modelos tampoco pueden estarlo.
  bool get _marcaEsLibre => _tipoId == _kOtro || _marcaId == _kOtro;
  bool get _modeloEsLibre => _marcaEsLibre || _modeloId == _kOtro;

  /// Sin catálogo el paso entero cae a texto libre y el alta sigue. No es un
  /// respaldo de cortesía: es un requisito — al otro lado hay una persona que
  /// quiere empezar a trabajar hoy.
  bool _soloTextoLibre(AltaConductorViewModel vm) => !vm.hayCatalogo;

  CatalogoVehiculos? get _catalogo => _catalogoVm;
  CatalogoVehiculos? _catalogoVm;

  void _elegirTipo(int? id) {
    setState(() {
      _tipoId = id;
      // Cambiar de tipo limpia marca y modelo: las marcas de un tipo no son las
      // de otro, y dejar el modelo anterior enseña un árbol que no existe.
      _marcaId = null;
      _modeloId = null;
      _modeloLibre.clear();
      if (id != _kOtro) _marcaLibre.clear();
    });
  }

  void _elegirMarca(int? id) {
    setState(() {
      _marcaId = id;
      // Cambiar de marca invalida el modelo: una Boxer no es una Yamaha.
      _modeloId = null;
      _modeloLibre.clear();
      if (id != _kOtro) _marcaLibre.clear();
    });
  }

  bool _valido(AltaConductorViewModel vm) => _faltantes(vm).isEmpty;

  /// Qué le falta al conductor para poder enviar (se muestra bajo el botón).
  List<String> _faltantes(AltaConductorViewModel vm) => [
        if (!_vehiculoDefinido) 'decirnos cuál es tu vehículo',
        if (_placa.text.trim().length < 5) 'la placa completa',
        if (!vm.tieneCedula) 'la foto de tu cédula',
      ];

  bool get _motoLista =>
      _vehiculoDefinido && _placa.text.trim().length >= 5;

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
        // La cédula es lo mínimo para enviar; el resto se puede completar luego.
        0 => vm.tieneCedula,
        1 => _motoLista,
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
      // Uno de los dos, nunca los dos: con referencia el texto lo compone el
      // servidor a partir del catálogo.
      vehiculo: _vehiculoLibre,
      modeloVehiculoId: _modeloVehiculoId,
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
    // El árbol se copia aquí para que los getters de este State puedan resolver
    // lo elegido sin recibirlo por parámetro en cada uno.
    _catalogoVm = vm.catalogo;

    // Si el perfil ya está completo, saltar directo a Inicio.
    if (!vm.cargando && vm.perfilCompleto && !_saltoAplicado) {
      _saltoAplicado = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Rutas.inicio);
      });
    }

    if (vm.cargando) {
      return Scaffold(
        appBar: encabezado('Completa tu perfil',
            onAtras: () => context.go(Rutas.inicio)),
        body: const CargandoConMensaje('Cargando tus datos…'),
      );
    }

    return PopScope(
      // El gesto de atrás retrocede de paso; solo sale desde el primero.
      canPop: _paso == 0,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _atras();
      },
      child: Scaffold(
        appBar: encabezado('Completa tu perfil', onAtras: _atras),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label),
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
                    // Los pasos van agrupados por **lo que documentan**, no por
                    // tipo de dato: antes las cuatro fotos iban juntas y los
                    // datos de la moto en otro paso, así que la tarjeta de
                    // propiedad quedaba a dos pantallas de la placa que aparece
                    // en ella. Ahora quien va a fotografiar la moto lo hace todo
                    // de una vez, junto a la moto.
                    _PasoIdentidad(
                      vm: vm,
                      onCedula: () => _tomarCedula(vm),
                      onSelfie: () => _tomarSelfie(vm),
                    ),
                    _PasoMoto(
                      vm: vm,
                      soloTextoLibre: _soloTextoLibre(vm),
                      tipoId: _tipoId,
                      marcaId: _marcaId,
                      modeloId: _modeloId,
                      tipo: _tipo,
                      marcaElegida: _marcaElegida,
                      modeloElegido: _modeloElegido,
                      marcaLibre: _marcaLibre,
                      modeloLibre: _modeloLibre,
                      marcaEsLibre: _marcaEsLibre,
                      modeloEsLibre: _modeloEsLibre,
                      placa: _placa,
                      licencia: _licencia,
                      onTipo: _elegirTipo,
                      onMarca: _elegirMarca,
                      onModelo: (m) => setState(() => _modeloId = m),
                      onCambio: () => setState(() {}),
                      onReintentarCatalogo: vm.cargarCatalogo,
                      onPapeles: () => _tomarPapeles(vm),
                      onFotoMoto: () => _tomarFotoMoto(vm),
                    ),
                    _PasoRevision(
                      vm: vm,
                      motoLista: _motoLista,
                      vehiculo: _vehiculoParaVer,
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
        0 => 'Tu identidad',
        1 => 'Tu vehículo',
        _ => 'Revisar y enviar',
      };

  /// Qué falta **de este paso**, no del alta entera. Decirle a alguien en el
  /// paso de la identidad que le falta la placa es ruido: todavía no ha llegado.
  String? _faltaEnEstePaso(AltaConductorViewModel vm) {
    if (_paso == 0 && !vm.tieneCedula) {
      return 'La foto de tu cédula es la única obligatoria para enviar.';
    }
    if (_paso == 1) {
      if (!_vehiculoDefinido) {
        return 'Dinos qué vehículo tienes: el tipo, la marca y el modelo.';
      }
      if (_placa.text.trim().length < 5) return 'Escribe la placa completa.';
      return null;
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

/// Paso 2 · el vehículo: tipo, marca, modelo, placa, municipio, licencia y
/// **sus dos fotos**.
///
/// La tarjeta de propiedad y la foto del vehículo viven aquí, junto a la placa
/// que aparece en las dos. Estaban a dos pasos de distancia y eso obligaba a ir
/// y volver para comprobar que coincidían.
///
/// **Los tres desplegables salen del catálogo del servidor**, no de una lista
/// compilada dentro de la app: cargar una marca en el panel la pone aquí sin
/// publicar una versión. Cada nivel queda deshabilitado hasta que se elija el
/// anterior, y los tres conservan su salida a texto libre.
///
/// **Añadir un nivel no añade un paso**: los tres son la misma pregunta —«cuál
/// es tu vehículo»— y partirla dejaría la placa y sus dos documentos separados
/// del dato que documentan.
class _PasoMoto extends StatelessWidget {
  const _PasoMoto({
    required this.vm,
    required this.soloTextoLibre,
    required this.tipoId,
    required this.marcaId,
    required this.modeloId,
    required this.tipo,
    required this.marcaElegida,
    required this.modeloElegido,
    required this.marcaLibre,
    required this.modeloLibre,
    required this.marcaEsLibre,
    required this.modeloEsLibre,
    required this.placa,
    required this.licencia,
    required this.onTipo,
    required this.onMarca,
    required this.onModelo,
    required this.onCambio,
    required this.onReintentarCatalogo,
    required this.onPapeles,
    required this.onFotoMoto,
  });

  final AltaConductorViewModel vm;
  final bool soloTextoLibre;
  final int? tipoId;
  final int? marcaId;
  final int? modeloId;
  final TipoVehiculo? tipo;
  final MarcaVehiculo? marcaElegida;
  final ModeloVehiculo? modeloElegido;
  final TextEditingController marcaLibre;
  final TextEditingController modeloLibre;
  final bool marcaEsLibre;
  final bool modeloEsLibre;
  final TextEditingController placa;
  final TextEditingController licencia;
  final ValueChanged<int?> onTipo;
  final ValueChanged<int?> onMarca;
  final ValueChanged<int?> onModelo;
  final VoidCallback onCambio;
  final VoidCallback onReintentarCatalogo;
  final VoidCallback onPapeles;
  final VoidCallback onFotoMoto;

  /// La silueta con la que se pinta lo que no tiene imagen. Del **tipo**
  /// elegido, y genérica mientras no haya ninguno.
  IconoVehiculo get _silueta => tipo?.icono ?? IconoVehiculo.otro;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const Text('Cuéntanos de tu vehículo', style: AppText.display),
        const SizedBox(height: AppSpacing.xs),
        const Text(
            'Los datos y las dos fotos del vehículo. Aprovecha que estás junto '
            'a él y hazlo todo de una vez.',
            style: TextStyle(color: AppColors.inkMuted)),
        const SizedBox(height: AppSpacing.xl),
        if (soloTextoLibre)
          ..._camposLibres(context)
        else
          ..._desplegables(context),
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
        const SizedBox(height: AppSpacing.xl),
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
          icon: Icons.two_wheeler_outlined,
          titulo: 'Foto de tu vehículo',
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

  /// Los tres desplegables encadenados, con «Otro» al final de cada uno.
  ///
  /// **Las imágenes se piden solo de lo que está en pantalla.** Los modelos que
  /// se construyen son los de la marca elegida y ninguno más, así que las fotos
  /// de los modelos de las demás marcas no se bajan nunca. Es la lección de la
  /// rejilla de aliados, donde construir la rejilla completa *era* descargar la
  /// foto de cada producto del municipio.
  List<Widget> _desplegables(BuildContext context) {
    final tipos = vm.catalogo?.tipos ?? const <TipoVehiculo>[];
    final marcas = tipo?.marcas ?? const <MarcaVehiculo>[];
    final modelos = marcaElegida?.modelos ?? const <ModeloVehiculo>[];
    return [
      // ── Tipo ──
      const _Label('Tipo de vehículo'),
      DropdownButtonFormField<int>(
        value: tipoId,
        isExpanded: true,
        items: [
          for (final t in tipos)
            DropdownMenuItem(
              value: t.id,
              child: _FilaDelCatalogo(
                nombre: t.nombre,
                imagenUrl: t.imagenUrl,
                icono: t.icono,
              ),
            ),
          const DropdownMenuItem(
            value: _AltaViewState._kOtro,
            child: Text('Otro'),
          ),
        ],
        onChanged: onTipo,
        decoration: const InputDecoration(
          hintText: 'Elige el tipo',
          prefixIcon: Icon(Icons.category_outlined),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      // ── Marca ──
      const _Label('Marca'),
      DropdownButtonFormField<int>(
        value: marcaId,
        isExpanded: true,
        items: [
          for (final m in marcas)
            DropdownMenuItem(
              value: m.id,
              child: _FilaDelCatalogo(
                nombre: m.nombre,
                imagenUrl: m.imagenUrl,
                icono: _silueta,
              ),
            ),
          const DropdownMenuItem(
            value: _AltaViewState._kOtro,
            child: Text('Otra'),
          ),
        ],
        // Sin tipo elegido no hay marcas que ofrecer: un desplegable que se abre
        // y no muestra nada parece la app rota.
        onChanged: tipoId == null || tipoId == _AltaViewState._kOtro
            ? null
            : onMarca,
        decoration: InputDecoration(
          hintText: tipoId == null ? 'Elige primero el tipo' : 'Elige la marca',
          prefixIcon: const Icon(Icons.sell_outlined),
        ),
      ),
      if (marcaEsLibre) ...[
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: marcaLibre,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => onCambio(),
          decoration: const InputDecoration(hintText: '¿Qué marca es?'),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      // ── Modelo ──
      const _Label('Modelo'),
      DropdownButtonFormField<int>(
        value: modeloId,
        isExpanded: true,
        items: [
          for (final m in modelos)
            DropdownMenuItem(
              value: m.id,
              child: _FilaDelCatalogo(
                nombre: m.nombre,
                imagenUrl: m.imagenUrl,
                icono: _silueta,
              ),
            ),
          const DropdownMenuItem(
            value: _AltaViewState._kOtro,
            child: Text('Otro'),
          ),
        ],
        onChanged: marcaId == null || marcaEsLibre ? null : onModelo,
        decoration: InputDecoration(
          hintText:
              marcaId == null ? 'Elige primero la marca' : 'Elige el modelo',
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
      // Lo elegido, con su imagen a la vista. Es una sola imagen más, y es la
      // que confirma que se eligió lo que se quería.
      if (modeloElegido != null) ...[
        const SizedBox(height: AppSpacing.lg),
        MotoCard(
          child: Row(
            children: [
              ImagenDeVehiculo(
                url: modeloElegido!.imagenUrl,
                icono: _silueta,
                tamano: 72,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${marcaElegida!.nombre} ${modeloElegido!.nombre}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.subtitle),
                    Text(tipo!.nombre, style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  /// El paso sin catálogo: dos campos de texto y el alta sigue.
  ///
  /// **No es un respaldo de cortesía, es un requisito.** Un catálogo que no
  /// llegó no puede impedirle registrarse a nadie: al otro lado hay una persona
  /// que quiere empezar a trabajar hoy, y un bache de red no puede costarle el
  /// día. Reintentar se ofrece solo cuando la consulta **falló** — reintentar un
  /// catálogo que el servidor dice que está vacío no arregla nada.
  List<Widget> _camposLibres(BuildContext context) {
    return [
      MotoCard(
        color: AppColors.primarySurface,
        child: Row(
          children: [
            Icon(
                vm.cargandoCatalogo
                    ? Icons.hourglass_top_rounded
                    : Icons.edit_note_rounded,
                color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                vm.cargandoCatalogo
                    ? 'Estamos cargando la lista de vehículos…'
                    : 'No pudimos cargar la lista de vehículos. Escríbelo a '
                        'mano y sigue: tu solicitud se envía igual.',
                style: AppText.body,
              ),
            ),
            if (vm.catalogoFallo && !vm.cargandoCatalogo)
              TextButton(
                onPressed: onReintentarCatalogo,
                child: const Text('Reintentar'),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      const _Label('Marca'),
      TextField(
        controller: marcaLibre,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => onCambio(),
        decoration: const InputDecoration(
          hintText: '¿Qué marca es?',
          prefixIcon: Icon(Icons.sell_outlined),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      const _Label('Modelo'),
      TextField(
        controller: modeloLibre,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => onCambio(),
        decoration: const InputDecoration(
          hintText: '¿Qué modelo es?',
          prefixIcon: Icon(Icons.confirmation_number_outlined),
        ),
      ),
    ];
  }
}

/// Una fila del desplegable: la imagen —o la silueta de su tipo— y el nombre.
class _FilaDelCatalogo extends StatelessWidget {
  const _FilaDelCatalogo({
    required this.nombre,
    required this.imagenUrl,
    required this.icono,
  });

  final String nombre;
  final String? imagenUrl;
  final IconoVehiculo icono;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ImagenDeVehiculo(url: imagenUrl, icono: icono),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// Paso 1 · quién eres: la cédula y la selfie que la respalda.
///
/// Van juntas porque son la misma pregunta —"¿esta cédula es tuya?"— y porque
/// las dos se toman en el mismo sitio y en el mismo minuto. Nada de la moto
/// aparece aquí.
class _PasoIdentidad extends StatelessWidget {
  const _PasoIdentidad({
    required this.vm,
    required this.onCedula,
    required this.onSelfie,
  });

  final AltaConductorViewModel vm;
  final VoidCallback onCedula;
  final VoidCallback onSelfie;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const Text('Empecemos por ti', style: AppText.display),
        const SizedBox(height: AppSpacing.xs),
        const Text(
            'Dos fotos para confirmar quién eres. Con la cédula ya puedes '
            'enviar tu solicitud; la selfie hace falta para habilitarte.',
            style: TextStyle(color: AppColors.inkMuted)),
        // De quién es la cuenta a la que se le añade el perfil. Quien llega aquí
        // desde su cuenta de siempre —el camino normal— necesita ver que no se le
        // está creando una segunda, y que su nombre, su celular, su correo y su
        // cédula ya están y no se los van a volver a pedir.
        if (vm.cuenta != null) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.account_circle_outlined,
                  size: 18, color: AppColors.inkMuted),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Con tu cuenta de Zumbeo: ${vm.cuenta!.nombre}'
                  '${vm.cuenta!.telefono != null ? ' · ${vm.cuenta!.telefono}' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _DocCard(
          icon: Icons.badge_outlined,
          titulo: 'Foto de tu cédula',
          subtitulo: 'Solo el lado de adelante (donde está tu foto)',
          etiqueta: 'Necesaria para enviar',
          // Tinta: es texto, y el naranja de marca sobre blanco da 3,1:1.
          etiquetaColor: AppColors.primaryInk,
          archivo: vm.cedula,
          accion: 'Tomar foto',
          onElegir: onCedula,
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
        const Text('Revisa y envía', style: AppText.display),
        const SizedBox(height: AppSpacing.xs),
        const Text(
            'Esto es lo que verá el administrador. Puedes volver a cualquier '
            'paso para cambiarlo.',
            style: TextStyle(color: AppColors.inkMuted)),
        const SizedBox(height: AppSpacing.lg),
        MotoCard(
          onTap: () => onIrAPaso(1),
          child: Row(
            children: [
              const Icon(Icons.two_wheeler_rounded, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehiculo ?? 'Sin definir',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.subtitle),
                    Text(placa.isEmpty ? 'Sin placa' : 'Placa $placa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption),
                    if (vm.municipioElegido != null)
                      Text(vm.municipioElegido!.etiqueta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption),
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
          // A la identidad: la cédula es lo único que bloquea el envío, así que
          // es donde tiene sentido caer si algo falta.
          onTap: () => onIrAPaso(0),
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.line)),
        // Barra anclada: la sombra va hacia arriba, que es la única dirección
        // en la que hay contenido del que separarse.
        boxShadow: AppElevation.anclada,
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
              style: AppText.caption,
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
            // `Expanded` y no `Spacer` entre los dos: una fila con un espaciador
            // rígido en medio no se puede recortar, y con la escala al 130 % el
            // texto empujaba al porcentaje fuera de la pantalla.
            Expanded(
              child: Text(
                completo
                    ? '¡Listo! Ya puedes enviar tu solicitud'
                    : 'Ya llevas $hechos de $total',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.subtitle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('${(fraccion * 100).round()}%',
                // `primaryInk` y no `primary`: el naranja de marca como texto
                // sobre blanco da 3,1:1.
                style: AppText.subtitle.copyWith(
                    color: AppColors.primaryInk,
                    fontWeight: AppText.fuerte)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: fraccion),
            // La misma duración y la misma curva que el cambio de paso
            // (`_paginas.animateToPage`). Iban a 400 ms contra 250: dos
            // transiciones de duraciones distintas sobre el mismo gesto se leen
            // como un salto, no como un avance.
            duration: const Duration(milliseconds: 250),
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
              style: AppText.body.copyWith(
                color: hecho ? AppColors.ink : AppColors.inkMuted,
                fontWeight: hecho ? AppText.medio : AppText.regular,
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.label),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.subtitle),
                const SizedBox(height: 2),
                Text(subtitulo, style: AppText.caption),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (adjuntado) ...[
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 16),
                      const SizedBox(width: 4),
                      // Tinta y no relleno: `success` sobre blanco da 2,74:1
                      // contra su propia superficie y no llega a AA.
                      Text('Foto lista',
                          style: AppText.caption.copyWith(
                              color: AppColors.successInk,
                              fontWeight: AppText.fuerte)),
                    ] else
                      Text(etiqueta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                              color: etiquetaColor,
                              fontWeight: AppText.fuerte)),
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
            const Text('Foto de tu cédula', style: AppText.title),
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
            child: Text('$numero. $texto', style: AppText.body),
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
            Text(titulo, style: AppText.title),
            const SizedBox(height: AppSpacing.xs),
            Text(mensaje,
                style: AppText.body.copyWith(color: AppColors.inkMuted)),
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
          Expanded(
            child: Text(
              'Revisaremos tus documentos y habilitaremos tu cuenta. Te avisaremos cuando puedas empezar a recibir pedidos.',
              style: AppText.body,
            ),
          ),
        ],
      ),
    );
  }
}

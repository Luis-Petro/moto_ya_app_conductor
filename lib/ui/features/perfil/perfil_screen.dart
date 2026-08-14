import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../di/locator.dart';
import '../../../domain/models/conductor.dart';
import '../../core/format/formato.dart';
import '../../core/tab_activa.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/beta_chip.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/confirmar_baja_dialog.dart';
import '../../core/widgets/legal.dart';
import '../../core/widgets/moto_card.dart';
import '../../core/widgets/phone_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../router.dart';
import 'perfil_view_model.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PerfilViewModel(
        locator<UsuarioRepository>(),
        locator<ConductorRepository>(),
        locator<AuthRepository>(),
        locator<TabActiva>(),
      )..cargar(),
      child: const _PerfilView(),
    );
  }
}

class _PerfilView extends StatefulWidget {
  const _PerfilView();

  @override
  State<_PerfilView> createState() => _PerfilViewState();
}

class _PerfilViewState extends State<_PerfilView> {
  // Sin controladores de texto: en esta pantalla no se escribe nada. Nombre,
  // correo y celular son datos de lectura con su propio flujo de cambio.

  void _aviso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Cambia al tab de Billetera.
  ///
  /// Van las dos cosas porque hacen dos cosas distintas: `go` cambia la rama del
  /// StatefulShellRoute, y `TabActiva` avisa al view model de ese tab de que
  /// vuelve a estar visible. El shell conserva los tabs en un `IndexedStack`, así
  /// que sin el segundo la Billetera se mostraría con las cifras de la última vez.
  static void _irABilletera(BuildContext context) {
    context.go(Rutas.billetera);
    locator<TabActiva>().cambiar(TabActiva.billetera);
  }

  Future<void> _cambiarFoto(PerfilViewModel vm) async {
    final ok = await vm.cambiarFoto();
    if (ok == null || !mounted) return;
    _aviso(ok ? 'Foto actualizada' : (vm.error ?? 'No se pudo subir la foto'));
  }

  /// Flujo de cambio de correo en dos pasos (código al correo nuevo).
  Future<void> _cambiarCorreo(PerfilViewModel vm) async {
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    var paso = 1;
    String? errorLocal;
    var ocupado = false;
    var exito = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> enviar() async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) {
                setSheet(() => errorLocal = 'Escribe un correo');
                return;
              }
              setSheet(() {
                ocupado = true;
                errorLocal = null;
              });
              final err = await vm.solicitarCambioCorreo(email);
              setSheet(() {
                ocupado = false;
                errorLocal = err;
                if (err == null) paso = 2;
              });
            }

            Future<void> confirmar() async {
              setSheet(() {
                ocupado = true;
                errorLocal = null;
              });
              final err = await vm.confirmarCambioCorreo(codeCtrl.text.trim());
              if (err == null) {
                exito = true;
                if (ctx.mounted) Navigator.pop(ctx);
                return;
              }
              setSheet(() {
                ocupado = false;
                errorLocal = err;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                top: AppSpacing.xl,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paso == 1 ? 'Cambiar correo' : 'Verifica tu correo',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    paso == 1
                        ? 'Te enviaremos un código al correo nuevo para confirmar que es tuyo.'
                        : 'Escribe el código que enviamos a ${emailCtrl.text.trim()}.',
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (paso == 1)
                    TextField(
                      controller: emailCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo nuevo',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    )
                  else
                    TextField(
                      controller: codeCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Código',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                  if (errorLocal != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      errorLocal!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: paso == 1 ? 'Enviar código' : 'Confirmar',
                    loading: ocupado,
                    onPressed: paso == 1 ? enviar : confirmar,
                  ),
                  if (paso == 2)
                    TextButton(
                      onPressed: ocupado ? null : enviar,
                      child: const Text('Reenviar código'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    emailCtrl.dispose();
    codeCtrl.dispose();
    if (exito && mounted) _aviso('Correo actualizado');
  }

  /// Flujo de cambio de celular en dos pasos (OTP al número nuevo). Mismo
  /// patrón que el correo: el número no se aplica hasta comprobar que es tuyo.
  Future<void> _cambiarCelular(PerfilViewModel vm) async {
    final telCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    var paso = 1;
    String? errorLocal;
    var ocupado = false;
    var exito = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> enviar() async {
              final tel = telCtrl.text.trim();
              if (tel.isEmpty) {
                setSheet(() => errorLocal = 'Escribe tu celular nuevo');
                return;
              }
              setSheet(() {
                ocupado = true;
                errorLocal = null;
              });
              final err = await vm.solicitarCambioCelular(tel);
              setSheet(() {
                ocupado = false;
                errorLocal = err;
                if (err == null) paso = 2;
              });
            }

            Future<void> confirmar() async {
              setSheet(() {
                ocupado = true;
                errorLocal = null;
              });
              final err = await vm.confirmarCambioCelular(codeCtrl.text.trim());
              if (err == null) {
                exito = true;
                if (ctx.mounted) Navigator.pop(ctx);
                return;
              }
              setSheet(() {
                ocupado = false;
                errorLocal = err;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                top: AppSpacing.xl,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paso == 1 ? 'Cambiar celular' : 'Verifica tu celular',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    paso == 1
                        ? 'Te enviaremos un código al número nuevo para confirmar que es tuyo.'
                        : 'Escribe el código que enviamos a ${telCtrl.text.trim()}.',
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (paso == 1)
                    PhoneField(controller: telCtrl)
                  else
                    TextField(
                      controller: codeCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Código',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                  if (errorLocal != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      errorLocal!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: paso == 1 ? 'Enviar código' : 'Confirmar',
                    loading: ocupado,
                    onPressed: paso == 1 ? enviar : confirmar,
                  ),
                  if (paso == 2)
                    TextButton(
                      onPressed: ocupado ? null : enviar,
                      child: const Text('Reenviar código'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    telCtrl.dispose();
    codeCtrl.dispose();
    if (exito && mounted) _aviso('Celular actualizado');
  }

  /// Qué falta, en una línea. Con todo subido dice lo que el conductor quiere
  /// leer; con algo pendiente, exactamente qué.
  String _resumenDocumentos(Conductor conductor) {
    final faltantes = conductor.documentosFaltantes;
    if (faltantes.isEmpty) {
      return conductor.documentosEnFirme
          ? 'Los 4 verificados'
          : 'Los 4 subidos, en revisión';
    }
    if (faltantes.length == 1) {
      return 'Falta ${faltantes.first}';
    }
    return 'Faltan ${faltantes.length} de ${DocumentoConductor.values.length}';
  }

  Future<void> _confirmarSalir(PerfilViewModel vm) async {
    // useRootNavigator: false — dentro de un tab del StatefulShellRoute el
    // navigator raíz pinta un velo negro sobre el shell (pantalla en negro).
    final salir = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (salir == true) await vm.cerrarSesion();
  }

  /// Verifica el correo o el celular que la cuenta ya tiene: un solo paso
  /// (código), porque el destino no se elige — es el dato guardado.
  Future<void> _verificarActual({
    required String titulo,
    required String destino,
    required Future<String?> Function() solicitar,
    required Future<String?> Function(String codigo) confirmar,
    required String avisoExito,
  }) async {
    final primerEnvio = await solicitar();
    if (!mounted) return;
    if (primerEnvio != null) {
      _aviso(primerEnvio);
      return;
    }

    final codeCtrl = TextEditingController();
    var ocupado = false;
    String? errorLocal;
    var exito = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> enviar() async {
              setSheet(() {
                ocupado = true;
                errorLocal = null;
              });
              final err = await solicitar();
              setSheet(() {
                ocupado = false;
                errorLocal = err;
              });
            }

            Future<void> confirmarCodigo() async {
              setSheet(() {
                ocupado = true;
                errorLocal = null;
              });
              final err = await confirmar(codeCtrl.text.trim());
              if (err == null) {
                exito = true;
                if (ctx.mounted) Navigator.pop(ctx);
                return;
              }
              setSheet(() {
                ocupado = false;
                errorLocal = err;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                top: AppSpacing.xl,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Escribe el código que enviamos a $destino.',
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: codeCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Código',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  if (errorLocal != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      errorLocal!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Confirmar',
                    loading: ocupado,
                    onPressed: confirmarCodigo,
                  ),
                  TextButton(
                    onPressed: ocupado ? null : enviar,
                    child: const Text('Reenviar código'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    codeCtrl.dispose();
    if (exito && mounted) _aviso(avisoExito);
  }

  Future<void> _verificarCorreoActual(PerfilViewModel vm) {
    return _verificarActual(
      titulo: 'Verifica tu correo',
      destino: vm.usuario?.email ?? 'tu correo',
      solicitar: vm.solicitarVerificacionCorreoActual,
      confirmar: vm.confirmarVerificacionCorreoActual,
      avisoExito: 'Correo verificado',
    );
  }

  Future<void> _verificarCelularActual(PerfilViewModel vm) {
    return _verificarActual(
      titulo: 'Verifica tu celular',
      destino: vm.usuario?.telefono ?? 'tu celular',
      solicitar: vm.solicitarVerificacionCelularActual,
      confirmar: vm.confirmarVerificacionCelularActual,
      avisoExito: 'Celular verificado',
    );
  }

  /// Baja de cuenta. El diálogo dice qué se borra y qué se conserva, porque es
  /// irreversible; y menciona la deuda, que es el motivo más probable de rechazo.
  Future<void> _confirmarEliminarCuenta(PerfilViewModel vm) async {
    final eliminar = await ConfirmarBajaDialog.pedir(
      context,
      descripcion:
          'Se borran tu nombre, correo, celular, cédula, tu foto y tus documentos '
          '(cédula, tarjeta de propiedad, selfie y foto de la moto). Tu historial de '
          'pedidos y de comisiones se conserva sin tus datos, porque son cuentas '
          'compartidas con la plataforma y con tus clientes.\n\n'
          'No se puede deshacer, y necesitas estar al día con tus comisiones.',
    );
    if (!eliminar) return;
    final error = await vm.eliminarCuenta();
    // Si salió bien, el router ya se llevó al conductor fuera (sesión cerrada);
    // solo queda contar el motivo cuando el backend lo rechaza.
    if (error != null && mounted) _aviso(error);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PerfilViewModel>();
    final conductor = vm.conductor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          // Cerrar sesión SIEMPRE accesible: aunque el perfil no cargue (401 o
          // error de red), el conductor debe poder salir y no quedar atrapado.
          //
          // Solo en ese caso, que es el que motivó el icono. Con el perfil
          // cargado, la salida es el botón del pie —el que se alcanza con el
          // pulgar— y el icono era un segundo "cerrar sesión" compitiendo por la
          // atención en la esquina más lejana de la mano.
          if (vm.cargando || vm.usuario == null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: () => _confirmarSalir(vm),
            ),
        ],
      ),
      body: SafeArea(
        child: vm.cargando
            ? const Center(child: CircularProgressIndicator())
            : vm.usuario == null
            ? ErrorRetry(
                message: vm.error ?? 'No pudimos cargar tu perfil',
                onRetry: vm.cargar,
              )
            : RefreshIndicator(
                onRefresh: vm.cargar,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: vm.subiendoFoto ? null : () => _cambiarFoto(vm),
                        child: _FotoPerfil(
                          fotoUrl: conductor?.fotoUrl,
                          iniciales: vm.usuario!.iniciales,
                          cargando: vm.subiendoFoto,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Enlace neutro, no naranja: la insignia de cámara sobre
                    // el avatar ya dice que se toca. En esta pantalla el único
                    // elemento que debe destacar es el estado de la cuenta —es
                    // lo que decide si puede trabajar—, y con la insignia, el
                    // texto y cuatro botones más en naranja no destacaba
                    // ninguno.
                    Center(
                      child: TextButton.icon(
                        onPressed: vm.subiendoFoto
                            ? null
                            : () => _cambiarFoto(vm),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.inkMuted,
                        ),
                        icon: const Icon(Icons.photo_camera_outlined, size: 16),
                        label: Text(
                          conductor?.fotoUrl != null
                              ? 'Cambiar foto'
                              : 'Agregar foto',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: Text(
                        vm.usuario!.nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    // Un 5,0 sin ninguna entrega es una promesa que el
                    // conductor no hizo, y la primera calificación real lo
                    // baja de un golpe. Sin calificaciones se dice así.
                    if (conductor != null) ...[
                      const SizedBox(height: 4),
                      Center(
                        child: (conductor.calificacion ?? 0) > 0
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    conductor.calificacion!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (conductor.tasaAceptacion != null)
                                    Text(
                                      '  ·  ${conductor.tasaAceptacion!.toStringAsFixed(0)}% aceptación',
                                      style: const TextStyle(
                                        color: AppColors.inkMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              )
                            : const Text(
                                'Sin calificaciones aún',
                                style: TextStyle(
                                  color: AppColors.inkMuted,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ],
                    if (conductor != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      // La pregunta con la que se entra a esta pantalla es
                      // "¿estoy habilitado y cuánto debo?". Antes había que
                      // bajar hasta el final para responderla.
                      _CabeceraEstado(
                        conductor: conductor,
                        onVerSaldo: () => _irABilletera(context),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),

                    // Canal directo de queja/sugerencia hacia el operador.
                    // Va arriba, sin scroll: estaba al final, después de los
                    // documentos, y quien tiene un problema no baja tres
                    // pantallas para contarlo — simplemente no lo cuenta.
                    MotoCard(
                      onTap: () => context.push(Rutas.feedback),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ayúdanos a mejorar',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Envíanos una queja o una sugerencia',
                                  style: TextStyle(
                                    color: AppColors.inkMuted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.inkMuted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Nombre, correo y celular en la misma tarjeta.
                    //
                    // El nombre estaba en un `TextField` con `enabled: false`:
                    // eso lo pinta gris y con el borde apagado, y se lee como
                    // un campo vacío que no se puede llenar, no como un dato
                    // en firme. Ahora es una fila de lectura con su candado,
                    // igual que el correo y el celular, que tampoco se editan
                    // en línea (cada uno tiene su flujo verificado).
                    MotoCard(
                      child: Column(
                        children: [
                          _FilaEnFirme(
                            etiqueta: 'Nombre',
                            icono: Icons.person_outline,
                            valor: vm.usuario!.nombre,
                            nota:
                                'Es tu identidad verificada y no se cambia '
                                'desde la app. Si necesitas corregirlo, '
                                'contáctanos.',
                          ),
                          const Divider(height: AppSpacing.lg),
                          _CredencialTile(
                            etiqueta: 'Correo',
                            icono: Icons.mail_outline,
                            valor: vm.usuario!.email,
                            vacio: 'Sin correo registrado',
                            verificado: (vm.usuario!.email ?? '').isEmpty
                                ? null
                                : vm.usuario!.emailVerificado,
                            onCambiar: () => _cambiarCorreo(vm),
                            onVerificar: () => _verificarCorreoActual(vm),
                          ),
                          const Divider(height: AppSpacing.lg),
                          _CredencialTile(
                            etiqueta: 'Celular',
                            icono: Icons.phone_outlined,
                            valor: vm.usuario!.telefono,
                            vacio: 'Sin celular registrado',
                            verificado: vm.usuario!.telefonoVerificado,
                            onCambiar: () => _cambiarCelular(vm),
                            onVerificar: () => _verificarCelularActual(vm),
                          ),
                        ],
                      ),
                    ),

                    if (conductor != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      const Text(
                        'VEHÍCULO Y DOCUMENTOS',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      MotoCard(
                        child: Column(
                          children: [
                            _InfoFila(
                              icon: Icons.two_wheeler_rounded,
                              label: 'Vehículo',
                              valor: conductor.vehiculo ?? '—',
                            ),
                            const Divider(height: AppSpacing.lg),
                            _InfoFila(
                              icon: Icons.pin_outlined,
                              label: 'Placa',
                              valor: conductor.placa ?? '—',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Los documentos viven en su propia pantalla: eran la
                      // mitad de este perfil y aquí basta con saber si están.
                      MotoCard(
                        onTap: () async {
                          await context.push(Rutas.documentos);
                          // Al volver puede haber cambiado el estado de un
                          // documento. Recargar es más barato que compartir
                          // el view model entre dos rutas del shell.
                          if (context.mounted) await vm.cargar();
                        },
                        child: Row(
                          children: [
                            Icon(
                              conductor.documentosFaltantes.isEmpty
                                  ? Icons.verified_rounded
                                  : Icons.assignment_late_outlined,
                              color: conductor.documentosFaltantes.isEmpty
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mis documentos',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _resumenDocumentos(conductor),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color:
                                          conductor.documentosFaltantes.isEmpty
                                          ? AppColors.inkMuted
                                          : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.inkMuted,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    OutlinedButton.icon(
                      onPressed: () => _confirmarSalir(vm),
                      icon: const Icon(Icons.logout, color: AppColors.danger),
                      label: const Text(
                        'Cerrar sesión',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Requisito de las tiendas: quien crea una cuenta tiene
                    // que poder borrarla desde la app, sin escribirle a nadie.
                    TextButton(
                      onPressed: vm.eliminandoCuenta
                          ? null
                          : () => _confirmarEliminarCuenta(vm),
                      child: Text(
                        vm.eliminandoCuenta
                            ? 'Eliminando…'
                            : 'Eliminar mi cuenta',
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Alcanzables desde dentro de la app, que es lo que
                    // piden las tiendas. Abren la landing en el navegador.
                    const EnlacesLegales(),
                    const SizedBox(height: AppSpacing.sm),
                    const Center(
                      child: Text(
                        'Hecho en Colombia 🇨🇴',
                        style: TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    // Versión + beta: es la pantalla donde alguien mira
                    // antes de reportar un problema.
                    const Center(child: PieVersion()),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Avatar de perfil del conductor: foto real (si existe) o iniciales, con una
/// insignia de cámara y overlay de carga mientras se sube.
class _FotoPerfil extends StatelessWidget {
  const _FotoPerfil({
    required this.iniciales,
    this.fotoUrl,
    this.cargando = false,
  });
  final String iniciales;
  final String? fotoUrl;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // `InitialsAvatar` usa `foregroundImage`, así que las iniciales quedan
        // debajo como respaldo natural si la foto no carga. Con `backgroundImage`
        // y sin child —como estaba— una URL vencida dejaba un círculo vacío.
        InitialsAvatar(initials: iniciales, imageUrl: fotoUrl, radius: 40),
        if (cargando)
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.black45,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.photo_camera,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Fila de una credencial de acceso (correo o celular): valor actual, si está
/// verificada y el acceso a su flujo de cambio. Nunca se edita en línea.
class _CredencialTile extends StatelessWidget {
  const _CredencialTile({
    required this.etiqueta,
    required this.icono,
    required this.vacio,
    required this.onCambiar,
    this.valor,
    this.verificado,
    this.onVerificar,
  });

  final String etiqueta;
  final IconData icono;
  final String vacio;
  final String? valor;

  /// null cuando no aplica mostrar el estado (p. ej. el dato no existe).
  final bool? verificado;
  final VoidCallback onCambiar;

  /// Verificar el dato **actual** (sin cambiarlo). Nulo = no aplica.
  final VoidCallback? onVerificar;

  @override
  Widget build(BuildContext context) {
    final tiene = (valor ?? '').trim().isNotEmpty;

    // Etiqueta y valor arriba a ancho completo; las acciones abajo, en su propia
    // fila. Antes era una fila de tres columnas y el valor competía por el ancho
    // con dos `TextButton`: un correo normal se partía a mitad de palabra
    // ("luispetro1994res / paldo@gmail.co / m") en tres renglones. Un correo se
    // lee de un tirón o no se lee.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, color: AppColors.inkMuted, size: 20),
            const SizedBox(width: AppSpacing.md),
            Text(
              etiqueta.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
                letterSpacing: 0.4,
              ),
            ),
            if (tiene && verificado != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                verificado! ? Icons.verified_rounded : Icons.error_outline,
                size: 13,
                color: verificado! ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 3),
              Text(
                verificado! ? 'Verificado' : 'Sin verificar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: verificado! ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          tiene ? valor! : vacio,
          // Una línea con elipsis: un correo largo se corta al final, donde se
          // entiende que sigue, y no por la mitad de una palabra.
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: tiene ? AppColors.ink : AppColors.inkMuted,
          ),
        ),
        Row(
          children: [
            // "Verificar" solo cuando el dato existe y está sin verificar: antes
            // la única salida era "cambiarlo" por el mismo valor, que el backend
            // rechaza por unicidad.
            if (tiene && verificado == false && onVerificar != null)
              TextButton(
                onPressed: onVerificar,
                child: const Text('Verificar'),
              ),
            TextButton(
              onPressed: onCambiar,
              child: Text(tiene ? 'Cambiar' : 'Agregar'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Estado de la cuenta y deuda, en la primera pantalla.
///
/// Es lo que el conductor viene a mirar: si puede recibir pedidos y cuánto debe.
/// Antes estaba repartido entre esta pantalla, Inicio y Billetera, y la única
/// forma de saber si estaba habilitado era intentar ponerse en línea.
///
/// El estado lleva color **y** texto: hay quien mira el celular al sol y quien
/// no distingue el verde del naranja.
class _CabeceraEstado extends StatelessWidget {
  const _CabeceraEstado({required this.conductor, required this.onVerSaldo});

  final Conductor conductor;

  /// Ir a la Billetera. Es lo que el conductor quiere hacer justo después de
  /// leer un número que debe.
  final VoidCallback onVerSaldo;

  @override
  Widget build(BuildContext context) {
    final (texto, color, fondo, icono) = switch (conductor) {
      _ when conductor.rechazado => (
        'Cuenta rechazada',
        AppColors.danger,
        AppColors.dangerSurface,
        Icons.block_rounded,
      ),
      _ when conductor.bloqueadoPorDeuda => (
        'Bloqueado por deuda',
        AppColors.danger,
        AppColors.dangerSurface,
        Icons.lock_rounded,
      ),
      _ when conductor.enRevision => (
        'En revisión',
        AppColors.warning,
        AppColors.warningSurface,
        Icons.hourglass_top_rounded,
      ),
      _ => (
        'Habilitado',
        AppColors.success,
        AppColors.successSurface,
        Icons.verified_rounded,
      ),
    };

    return MotoCard(
      color: fondo,
      borderColor: color,
      child: Row(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ),
          // El bloque decide por sí mismo si tiene algo que decir: con la cuenta
          // al día no pinta nada y el estado ocupa la tarjeta entera.
          SaldoCabecera(conductor: conductor, onTap: onVerSaldo),
        ],
      ),
    );
  }
}

/// El saldo de la cabecera del perfil, resuelto por el **signo** de `deudaActual`.
///
/// `deudaActual` viene con signo del backend: en positivo son comisiones
/// pendientes, y en negativo es **saldo a favor** (un incentivo o una corrección
/// que registró el administrador). La cabecera pintaba el rótulo `DEUDA` fijo, así
/// que a quien tenía saldo a favor la pantalla que dice si puede trabajar le
/// decía que debía dinero. La Billetera ya lo distinguía bien (`saldoAFavor`) y
/// el perfil la contradecía sobre el mismo número.
///
/// Los tres casos —debe, tiene a favor, está al día— viven aquí y en un solo
/// sitio, para que un test los recorra de verdad. Es público por eso.
class SaldoCabecera extends StatelessWidget {
  const SaldoCabecera({
    super.key,
    required this.conductor,
    required this.onTap,
  });

  final Conductor conductor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Un `DEUDA $ 0` es ruido: obliga a leer un número para enterarse de que no
    // pasa nada. Con la cuenta al día, aquí no va nada.
    if (conductor.deudaActual.abs() < 1) return const SizedBox.shrink();

    final aFavor = conductor.deudaActual < 0;
    // El bloqueo manda sobre el signo: si no puede recibir pedidos, el número
    // que lo explica va en rojo aunque el rótulo diga otra cosa.
    final color = conductor.bloqueadoPorDeuda
        ? AppColors.danger
        : (aFavor ? AppColors.success : AppColors.ink);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              aFavor ? 'A FAVOR' : 'DEUDA',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
                letterSpacing: 0.4,
              ),
            ),
            Text(
              // Valor absoluto: "-$ 3.000 a favor" son dos negaciones que hay
              // que deshacer mentalmente para leer una buena noticia.
              Formato.moneda(conductor.deudaActual.abs()),
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoFila extends StatelessWidget {
  const _InfoFila({
    required this.icon,
    required this.label,
    required this.valor,
  });
  final IconData icon;
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.inkMuted),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: const TextStyle(color: AppColors.inkMuted)),
        const Spacer(),
        Text(
          valor,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

/// Dato que no se edita desde la app, presentado como dato.
///
/// Un `TextField` deshabilitado dice "esto se escribe, pero no ahora": el valor
/// se pinta gris sobre un borde apagado y a simple vista es un campo vacío. Un
/// candado dice "esto ya está decidido", que es lo que ocurre con el nombre una
/// vez validada la identidad.
class _FilaEnFirme extends StatelessWidget {
  const _FilaEnFirme({
    required this.etiqueta,
    required this.icono,
    required this.valor,
    this.nota,
  });

  final String etiqueta;
  final IconData icono;
  final String valor;

  /// Por qué no se edita. Va junto al dato, no al final del bloque: al final se
  /// lee después de haber buscado el botón que no existe.
  final String? nota;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: AppColors.inkMuted, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              if (nota != null) ...[
                const SizedBox(height: 3),
                Text(
                  nota!,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.sm, top: 2),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

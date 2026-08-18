import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/conductor_repository.dart';
import '../../../data/repositories/usuario_repository.dart';
import '../../../di/locator.dart';
import '../../../domain/models/conductor.dart';
import '../../core/tab_activa.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/elegir_foto_sheet.dart';
import '../../core/widgets/encabezado.dart';
import '../../core/widgets/moto_card.dart';
import '../../router.dart';
import 'perfil_view_model.dart';

/// Los cuatro documentos de habilitación, en su propia pantalla.
///
/// Salieron del perfil porque eran la mitad de su altura: quien entra a Perfil
/// viene a mirar cómo está su cuenta, no a gestionar cuatro fotos. La cabecera
/// del perfil responde "¿estoy bien?" y aquí entra solo el que tiene que actuar.
///
/// No es un acordeón por lo mismo: colapsado o no, quien tiene algo pendiente
/// seguiría teniendo el mismo scroll debajo.
class DocumentosScreen extends StatelessWidget {
  const DocumentosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PerfilViewModel(
        locator<UsuarioRepository>(),
        locator<ConductorRepository>(),
        locator<AuthRepository>(),
        locator<TabActiva>(),
      )..cargar(),
      child: const _DocumentosView(),
    );
  }
}

class _DocumentosView extends StatefulWidget {
  const _DocumentosView();

  @override
  State<_DocumentosView> createState() => _DocumentosViewState();
}

class _DocumentosViewState extends State<_DocumentosView> {
  void _aviso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Sube o reemplaza uno de los documentos de habilitación.
  Future<void> _subirDocumento(
      PerfilViewModel vm, DocumentoConductor doc) async {
    // La hoja compartida: aquí eran dos `ListTile` sueltos sobre el gris de
    // Material y sin salida visible más que tocar fuera. La guía del documento
    // pasa a ser el contexto, que es donde hace falta: son cuatro documentos y
    // la hoja no decía de cuál estaba hablando.
    final source = await elegirFotoSheet(
      context,
      titulo: doc.titulo,
      contexto: doc.guia,
    );
    if (source == null) return;
    final err = await vm.subirDocumento(doc, source);
    if (!mounted) return;
    _aviso(err ?? '${doc.titulo}: foto actualizada');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PerfilViewModel>();
    final conductor = vm.conductor;

    return Scaffold(
      appBar: encabezado('Mis documentos', onAtras: () => context.go(Rutas.perfil)),
      body: SafeArea(
        child: vm.cargando
            ? const CargandoConMensaje('Cargando tus documentos…')
            : conductor == null
                ? ErrorRetry(
                    message: vm.error ?? 'No pudimos cargar tus documentos',
                    onRetry: vm.cargar,
                    esRed: vm.errorEsRed,
                  )
                : RefreshIndicator(
                    onRefresh: vm.cargar,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      children: [
                        Text(
                          'Con estas cuatro fotos el administrador puede habilitarte '
                          'para recibir pedidos. Que se lean bien es lo único que '
                          'importa: sin recortes, sin brillos y con la placa visible.',
                          style: AppText.body.copyWith(color: AppColors.inkMuted),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _Documentos(
                          conductor: conductor,
                          vm: vm,
                          onSubir: (doc) => _subirDocumento(vm, doc),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

/// Los cuatro documentos con su estado y la opción de subir o reemplazar cada
/// uno. Mientras falte alguno, el admin no puede habilitar la cuenta: decirlo
/// aquí evita esperas sin saber a qué.
class _Documentos extends StatelessWidget {
  const _Documentos({
    required this.conductor,
    required this.vm,
    required this.onSubir,
  });

  final Conductor conductor;
  final PerfilViewModel vm;
  final void Function(DocumentoConductor) onSubir;

  @override
  Widget build(BuildContext context) {
    final faltantes = conductor.documentosFaltantes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MotoCard(
          child: Column(
            children: [
              for (var i = 0; i < DocumentoConductor.values.length; i++) ...[
                if (i > 0) const Divider(height: AppSpacing.lg),
                _FilaDocumento(
                  doc: DocumentoConductor.values[i],
                  url: conductor.urlDocumento(DocumentoConductor.values[i]),
                  subiendo:
                      vm.subiendoDocumento == DocumentoConductor.values[i],
                  enFirme: conductor.documentosEnFirme,
                  onSubir: () => onSubir(DocumentoConductor.values[i]),
                ),
              ],
            ],
          ),
        ),
        if (conductor.documentosEnFirme) ...[
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Tus documentos ya fueron verificados y no se pueden cambiar desde la '
            'app. Si alguno quedó mal (borroso, vencido), pídele al administrador '
            'que devuelva tu cuenta a revisión.',
            style: AppText.caption,
          ),
        ],
        if (faltantes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            conductor.habilitado
                ? 'Te falta subir: ${faltantes.join(', ')}.'
                : 'Para que te habiliten falta: ${faltantes.join(', ')}.',
            style: AppText.caption.copyWith(color: AppColors.warningInk),
          ),
        ],
      ],
    );
  }
}

class _FilaDocumento extends StatelessWidget {
  const _FilaDocumento({
    required this.doc,
    required this.url,
    required this.subiendo,
    required this.onSubir,
    this.enFirme = false,
  });

  final DocumentoConductor doc;
  final String? url;
  final bool subiendo;
  final VoidCallback onSubir;

  /// Ya verificada por un administrador: no se puede reemplazar desde la app.
  final bool enFirme;

  @override
  Widget build(BuildContext context) {
    final tiene = url != null;
    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: tiene
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: Image.network(url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.inkMuted)),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.warningSurface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.photo_camera_outlined,
                      size: 20, color: AppColors.warningInk),
                ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doc.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                  enFirme
                      ? 'Verificada'
                      : tiene
                          ? 'Subida'
                          : 'Pendiente',
                  style: AppText.caption.copyWith(
                      fontWeight: AppText.medio,
                      color: tiene ? AppColors.successInk : AppColors.warningInk)),
            ],
          ),
        ),
        if (subiendo)
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
        // Verificada: sin botón. Uno que siempre responde 409 es peor que no
        // tenerlo — el texto de arriba explica cómo pedir la corrección.
        else if (!enFirme)
          TextButton(
            onPressed: onSubir,
            child: Text(tiene ? 'Reemplazar' : 'Subir'),
          )
        else
          const Icon(Icons.lock_outline, size: 18, color: AppColors.inkMuted),
      ],
    );
  }
}

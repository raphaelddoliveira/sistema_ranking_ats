import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../viewmodel/bug_report_viewmodel.dart';

class BugReportScreen extends ConsumerStatefulWidget {
  const BugReportScreen({super.key});

  @override
  ConsumerState<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends ConsumerState<BugReportScreen> {
  final _descriptionController = TextEditingController();
  final _screenController = TextEditingController();
  String _reportType = 'bug';
  XFile? _screenshot;
  Uint8List? _screenshotPreview;

  @override
  void dispose() {
    _descriptionController.dispose();
    _screenController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _screenshot = file;
        _screenshotPreview = bytes;
      });
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Erro ao selecionar imagem: $e');
      }
    }
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      SnackbarUtils.showError(context, 'Descreva o problema');
      return;
    }

    final player = ref.read(currentPlayerProvider).valueOrNull;
    if (player == null) {
      SnackbarUtils.showError(context, 'Usuário não identificado');
      return;
    }

    final clubId = ref.read(currentClubIdProvider);
    final screen = _screenController.text.trim();

    final success = await ref.read(bugReportProvider.notifier).submit(
          playerId: player.id,
          clubId: clubId,
          reportType: _reportType,
          description: description,
          screenName: screen.isEmpty ? null : screen,
          screenshot: _screenshot,
        );

    if (!mounted) return;
    if (success) {
      SnackbarUtils.showSuccess(context, 'Obrigado pelo feedback!');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bugReportProvider);

    ref.listen(bugReportProvider, (_, s) {
      s.whenOrNull(
        error: (e, _) => SnackbarUtils.showError(context, 'Erro: $e'),
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Reportar Problema')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Descreva o problema com detalhes. Quanto mais informação, mais rápido resolvemos.',
                      style: TextStyle(fontSize: 12, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tipo
            const Text('Tipo', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'bug',
                  label: Text('Bug'),
                  icon: Icon(Icons.bug_report),
                ),
                ButtonSegment(
                  value: 'suggestion',
                  label: Text('Sugestão'),
                  icon: Icon(Icons.lightbulb_outline),
                ),
                ButtonSegment(
                  value: 'question',
                  label: Text('Dúvida'),
                  icon: Icon(Icons.help_outline),
                ),
              ],
              selected: {_reportType},
              onSelectionChanged: (v) => setState(() => _reportType = v.first),
            ),
            const SizedBox(height: 20),

            // Descrição
            const Text('Descrição *',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: 'Descreva o que aconteceu, o que esperava e o que ocorreu...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Tela onde ocorreu
            const Text('Tela onde ocorreu',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _screenController,
              decoration: const InputDecoration(
                hintText: 'Ex: Criar Desafio, Reservas, Ranking...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Screenshot
            const Text('Anexar imagem (opcional)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_screenshotPreview != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _screenshotPreview!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickScreenshot,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Trocar imagem'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _screenshot = null;
                        _screenshotPreview = null;
                      }),
                      icon: const Icon(Icons.close, color: AppColors.error),
                      label: const Text('Remover',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ),
                ],
              ),
            ] else
              OutlinedButton.icon(
                onPressed: _pickScreenshot,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Selecionar imagem'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),

            const SizedBox(height: 24),

            // Submit
            ElevatedButton.icon(
              onPressed: state.isLoading ? null : _submit,
              icon: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(state.isLoading ? 'Enviando...' : 'Enviar'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

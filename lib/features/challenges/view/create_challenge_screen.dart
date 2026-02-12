import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../viewmodel/challenge_list_viewmodel.dart';
import '../viewmodel/create_challenge_viewmodel.dart';

class CreateChallengeScreen extends ConsumerWidget {
  const CreateChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opponentsAsync = ref.watch(eligibleOpponentsProvider);
    final createState = ref.watch(createChallengeProvider);

    ref.listen(createChallengeProvider, (_, state) {
      state.whenOrNull(
        error: (error, _) {
          SnackbarUtils.showError(context, error.toString());
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Desafio'),
      ),
      body: opponentsAsync.when(
        data: (opponents) {
          if (opponents.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off, size: 64, color: AppColors.onBackgroundLight),
                    SizedBox(height: 16),
                    Text(
                      'Nenhum oponente disponivel',
                      style: TextStyle(fontSize: 16, color: AppColors.onBackgroundLight),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Voce so pode desafiar jogadores ate 2 posicoes acima no ranking.',
                      style: TextStyle(fontSize: 13, color: AppColors.onBackgroundLight),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Selecione seu oponente',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Jogadores ate 2 posicoes acima de voce',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onBackgroundMedium,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: opponents.length,
                  itemBuilder: (context, index) {
                    final opponent = opponents[index];
                    final isProtected =
                        opponent['challenged_protection_until'] != null &&
                            DateTime.parse(
                                    opponent['challenged_protection_until'])
                                .isAfter(DateTime.now());

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceVariant,
                          backgroundImage:
                              opponent['avatar_url'] != null
                                  ? CachedNetworkImageProvider(
                                      opponent['avatar_url'])
                                  : null,
                          child: opponent['avatar_url'] == null
                              ? Text(
                                  (opponent['full_name'] as String)
                                      .isNotEmpty
                                      ? (opponent['full_name'] as String)[0]
                                          .toUpperCase()
                                      : '?',
                                )
                              : null,
                        ),
                        title: Text(
                          opponent['full_name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Row(
                          children: [
                            Text('#${opponent['ranking_position']}'),
                            if (opponent['nickname'] != null) ...[
                              const Text(' - '),
                              Text(
                                '"${opponent['nickname']}"',
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic),
                              ),
                            ],
                            if (isProtected) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.shield,
                                  size: 14, color: AppColors.info),
                              const Text(
                                ' Protegido',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.info),
                              ),
                            ],
                          ],
                        ),
                        trailing: createState.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.sports_tennis),
                        enabled: !isProtected && !createState.isLoading,
                        onTap: isProtected || createState.isLoading
                            ? null
                            : () => _confirmChallenge(
                                context, ref, opponent),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erro: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(eligibleOpponentsProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmChallenge(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> opponent,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Desafio'),
        content: Text(
          'Deseja desafiar ${opponent['full_name']} (#${opponent['ranking_position']})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final challengeId = await ref
                  .read(createChallengeProvider.notifier)
                  .createChallenge(opponent['id'] as String);

              if (challengeId != null && context.mounted) {
                SnackbarUtils.showSuccess(context, 'Desafio criado!');
                ref.invalidate(activeChallengesProvider);
                context.pushReplacement('/challenges/$challengeId');
              }
            },
            child: const Text('Desafiar'),
          ),
        ],
      ),
    );
  }
}

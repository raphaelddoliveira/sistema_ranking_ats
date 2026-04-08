import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/club_member_model.dart';
import '../../challenges/viewmodel/challenge_list_viewmodel.dart';
import '../../challenges/viewmodel/create_challenge_viewmodel.dart';

class AdminCreateChallengeScreen extends ConsumerStatefulWidget {
  const AdminCreateChallengeScreen({super.key});

  @override
  ConsumerState<AdminCreateChallengeScreen> createState() =>
      _AdminCreateChallengeScreenState();
}

class _AdminCreateChallengeScreenState
    extends ConsumerState<AdminCreateChallengeScreen> {
  ClubMemberModel? _selectedChallenger;

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(allMembersProvider);
    final createState = ref.watch(createChallengeProvider);

    ref.listen(createChallengeProvider, (_, state) {
      state.whenOrNull(
        error: (error, _) {
          SnackbarUtils.showError(context, error.toString());
        },
      );
    });

    final step = _selectedChallenger == null ? 1 : 2;
    final title = step == 1
        ? 'Selecione o Desafiante'
        : 'Selecione o Desafiado';
    final subtitle = step == 1
        ? 'Quem vai desafiar?'
        : 'Desafiante: ${_selectedChallenger!.playerName} (#${_selectedChallenger!.rankingPosition})';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Desafio (Admin)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_selectedChallenger != null) {
              setState(() => _selectedChallenger = null);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: membersAsync.when(
        data: (members) {
          final list = step == 2
              ? members
                  .where((m) => m.playerId != _selectedChallenger!.playerId)
                  .toList()
              : members;

          if (list.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum membro disponível',
                style: TextStyle(color: AppColors.onBackgroundLight),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onBackgroundMedium,
                      ),
                ),
              ),
              if (step == 2)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _selectedChallenger = null),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Trocar desafiante'),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final member = list[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceVariant,
                          backgroundImage: member.playerAvatarUrl != null
                              ? CachedNetworkImageProvider(
                                  member.playerAvatarUrl!)
                              : null,
                          child: member.playerAvatarUrl == null
                              ? Text(
                                  member.playerName.isNotEmpty
                                      ? member.playerName[0].toUpperCase()
                                      : '?',
                                )
                              : null,
                        ),
                        title: Text(
                          member.playerName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Row(
                          children: [
                            Text('#${member.rankingPosition}'),
                            if (member.playerNickname != null) ...[
                              const Text(' - '),
                              Text(
                                '"${member.playerNickname}"',
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic),
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
                            : Icon(
                                step == 1 ? Icons.person : Icons.flash_on),
                        enabled: !createState.isLoading,
                        onTap: createState.isLoading
                            ? null
                            : () {
                                if (step == 1) {
                                  setState(
                                      () => _selectedChallenger = member);
                                } else {
                                  _confirmAdminChallenge(member);
                                }
                              },
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
                onPressed: () => ref.invalidate(allMembersProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAdminChallenge(ClubMemberModel challenged) {
    final challenger = _selectedChallenger!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Desafio'),
        content: Text(
          '${challenger.playerName} (#${challenger.rankingPosition}) '
          'vai desafiar ${challenged.playerName} (#${challenged.rankingPosition}).\n\n'
          'Nenhuma regra de cooldown ou posição será aplicada.',
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
                  .adminCreateChallenge(
                    challengerId: challenger.playerId,
                    challengedId: challenged.playerId,
                  );

              if (challengeId != null && mounted) {
                SnackbarUtils.showSuccess(
                    context, 'Desafio criado pelo admin!');
                ref.invalidate(activeChallengesProvider);
                ref.invalidate(upcomingChallengesProvider);
                ref.invalidate(allMembersProvider);
                setState(() => _selectedChallenger = null);
                context.pushReplacement('/challenges/$challengeId');
              }
            },
            child: const Text('Criar Desafio'),
          ),
        ],
      ),
    );
  }
}

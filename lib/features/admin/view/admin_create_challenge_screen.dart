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

  int get _step => _selectedChallenger == null ? 1 : 2;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Desafio'),
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
          final list = _step == 2
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
            children: [
              // Step indicator
              _StepIndicator(step: _step),

              // Selected challenger banner (step 2)
              if (_step == 2) _ChallengerBanner(
                challenger: _selectedChallenger!,
                onClear: () => setState(() => _selectedChallenger = null),
              ),

              // Instruction
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _step == 1
                        ? 'Quem vai DESAFIAR?'
                        : 'Quem será o DESAFIADO?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),

              // Members list
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final member = list[index];
                    return _MemberTile(
                      member: member,
                      isLoading: createState.isLoading,
                      onTap: () {
                        if (_step == 1) {
                          setState(() => _selectedChallenger = member);
                        } else {
                          _confirmAdminChallenge(member);
                        }
                      },
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${challenger.playerName} (#${challenger.rankingPosition})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.arrow_downward, color: AppColors.onBackgroundLight),
            ),
            Row(
              children: [
                const Icon(Icons.person_outline, color: AppColors.secondary, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${challenged.playerName} (#${challenged.rankingPosition})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.info),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Regras de cooldown e posição não serão aplicadas.',
                    style: TextStyle(fontSize: 12, color: AppColors.info),
                  )),
                ],
              ),
            ),
          ],
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
                SnackbarUtils.showSuccess(context, 'Desafio criado!');
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

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          _StepCircle(number: 1, label: 'Desafiante', isActive: step == 1, isDone: step > 1),
          Expanded(
            child: Container(
              height: 2,
              color: step > 1 ? AppColors.primary : AppColors.divider,
            ),
          ),
          _StepCircle(number: 2, label: 'Desafiado', isActive: step == 2, isDone: false),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int number;
  final String label;
  final bool isActive;
  final bool isDone;

  const _StepCircle({
    required this.number,
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive || isDone ? AppColors.primary : AppColors.onBackgroundLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isDone ? AppColors.primary : AppColors.surface,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: isActive ? Colors.white : color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _ChallengerBanner extends StatelessWidget {
  final ClubMemberModel challenger;
  final VoidCallback onClear;

  const _ChallengerBanner({required this.challenger, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withAlpha(30),
            backgroundImage: challenger.playerAvatarUrl != null
                ? CachedNetworkImageProvider(challenger.playerAvatarUrl!)
                : null,
            child: challenger.playerAvatarUrl == null
                ? Text(
                    challenger.playerName.isNotEmpty
                        ? challenger.playerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DESAFIANTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '${challenger.playerName} (#${challenger.rankingPosition})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Trocar desafiante',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final ClubMemberModel member;
  final bool isLoading;
  final VoidCallback onTap;

  const _MemberTile({
    required this.member,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceVariant,
          backgroundImage: member.playerAvatarUrl != null
              ? CachedNetworkImageProvider(member.playerAvatarUrl!)
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
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        trailing: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_ios, size: 14),
        enabled: !isLoading,
        onTap: isLoading ? null : onTap,
      ),
    );
  }
}

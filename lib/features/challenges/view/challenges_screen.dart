import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../core/extensions/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/challenge_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../../shared/widgets/like_button.dart';
import '../../clubs/view/club_selector_widget.dart';
import '../viewmodel/challenge_list_viewmodel.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: clubAppBarTitle('Desafios', context, ref),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ativos'),
              Tab(text: 'Histórico'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/challenges/create'),
          child: const Icon(Icons.add),
        ),
        body: const TabBarView(
          children: [
            _ActiveChallengesTab(),
            _HistoryChallengesTab(),
          ],
        ),
      ),
    );
  }
}

class _ActiveChallengesTab extends ConsumerWidget {
  const _ActiveChallengesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(activeChallengesProvider);
    final upcomingAsync = ref.watch(upcomingChallengesProvider);
    final pendingDateAsync = ref.watch(pendingDateChallengesProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);
    final playerId = currentPlayer.valueOrNull?.id;

    return challengesAsync.when(
      data: (challenges) {
        final upcoming = upcomingAsync.valueOrNull ?? [];
        final pendingDate = pendingDateAsync.valueOrNull ?? [];

        if (challenges.isEmpty && upcoming.isEmpty && pendingDate.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flash_on, size: 64, color: AppColors.onBackgroundLight),
                SizedBox(height: 16),
                Text(
                  'Nenhum desafio ativo',
                  style: TextStyle(fontSize: 16, color: AppColors.onBackgroundLight),
                ),
                SizedBox(height: 8),
                Text(
                  'Toque no + para criar um desafio',
                  style: TextStyle(fontSize: 13, color: AppColors.onBackgroundLight),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(activeChallengesProvider);
            ref.invalidate(upcomingChallengesProvider);
            ref.invalidate(pendingDateChallengesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Upcoming games card
              if (upcoming.isNotEmpty)
                _UpcomingGamesCard(upcoming: upcoming),
              // Pending date card
              if (pendingDate.isNotEmpty)
                _PendingDateCard(challenges: pendingDate),
              // Active challenges
              ...challenges.map((c) => _ChallengeListTile(
                challenge: c,
                currentPlayerId: playerId ?? '',
              )),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Erro: $error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(activeChallengesProvider),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingGamesCard extends StatefulWidget {
  final List<ChallengeModel> upcoming;

  const _UpcomingGamesCard({required this.upcoming});

  @override
  State<_UpcomingGamesCard> createState() => _UpcomingGamesCardState();
}

class _UpcomingGamesCardState extends State<_UpcomingGamesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.upcoming.length;
    final dateFormat = DateFormat('dd/MM HH:mm');

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withAlpha(20),
                AppColors.secondary.withAlpha(15),
              ],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.calendar_month, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Próximos jogos',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            '$count ${count == 1 ? 'jogo agendado' : 'jogos agendados'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onBackgroundMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.onBackgroundMedium,
                    ),
                  ],
                ),
              ),
              if (_expanded) ...[
                const Divider(height: 1),
                ...widget.upcoming.map((c) => ListTile(
                  dense: true,
                  onTap: () => context.push('/challenges/${c.id}'),
                  leading: Icon(Icons.sports_tennis, size: 18, color: AppColors.challengeScheduled),
                  title: Text(
                    '${c.challengerName ?? '?'} vs ${c.challengedName ?? '?'}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      c.chosenDate != null ? dateFormat.format(c.chosenDate!.toLocal()) : 'Data pendente',
                      if (c.courtName != null) c.courtName!,
                    ].join(' • '),
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.onBackgroundLight),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingDateCard extends StatefulWidget {
  final List<ChallengeModel> challenges;

  const _PendingDateCard({required this.challenges});

  @override
  State<_PendingDateCard> createState() => _PendingDateCardState();
}

class _PendingDateCardState extends State<_PendingDateCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.challenges.length;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                AppColors.warning.withAlpha(20),
                AppColors.warning.withAlpha(10),
              ],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.event_busy, color: AppColors.warning, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data não definida',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            '$count ${count == 1 ? 'desafio aguardando' : 'desafios aguardando'} agendamento',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onBackgroundMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.onBackgroundMedium,
                    ),
                  ],
                ),
              ),
              if (_expanded) ...[
                const Divider(height: 1),
                ...widget.challenges.map((c) => ListTile(
                  dense: true,
                  onTap: () => context.push('/challenges/${c.id}'),
                  leading: Icon(Icons.schedule, size: 18, color: AppColors.warning),
                  title: Text(
                    '${c.challengerName ?? '?'} vs ${c.challengedName ?? '?'}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Aguardando quadra e horário • ${c.createdAt.timeAgo()}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.onBackgroundLight),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryChallengesTab extends ConsumerStatefulWidget {
  const _HistoryChallengesTab();

  @override
  ConsumerState<_HistoryChallengesTab> createState() => _HistoryChallengesTabState();
}

class _HistoryChallengesTabState extends ConsumerState<_HistoryChallengesTab> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(
      _showAll ? allChallengeHistoryProvider : challengeHistoryProvider,
    );
    final upcomingAsync = ref.watch(upcomingChallengesProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);
    final playerId = currentPlayer.valueOrNull?.id;

    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Meus'),
                selected: !_showAll,
                onSelected: (_) => setState(() => _showAll = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Todos'),
                selected: _showAll,
                onSelected: (_) => setState(() => _showAll = true),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: historyAsync.when(
            data: (challenges) {
              final upcoming = upcomingAsync.valueOrNull ?? [];

              if (challenges.isEmpty && upcoming.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhum desafio finalizado',
                    style: TextStyle(fontSize: 16, color: AppColors.onBackgroundLight),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(
                    _showAll ? allChallengeHistoryProvider : challengeHistoryProvider,
                  );
                  ref.invalidate(upcomingChallengesProvider);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: challenges.length + (upcoming.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (upcoming.isNotEmpty && index == 0) {
                      return _UpcomingGamesCard(upcoming: upcoming);
                    }
                    final challengeIndex = upcoming.isNotEmpty ? index - 1 : index;
                    final challenge = challenges[challengeIndex];
                    return _showAll
                        ? _AllChallengeListTile(challenge: challenge)
                        : _ChallengeListTile(
                            challenge: challenge,
                            currentPlayerId: playerId ?? '',
                          );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Erro: $error')),
          ),
        ),
      ],
    );
  }
}

class _AllChallengeListTile extends ConsumerWidget {
  final ChallengeModel challenge;

  const _AllChallengeListTile({required this.challenge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengerName = challenge.challengerName ?? 'Jogador';
    final challengedName = challenge.challengedName ?? 'Jogador';

    final statusColor = switch (challenge.status) {
      ChallengeStatus.completed => AppColors.challengeCompleted,
      ChallengeStatus.woChallenger || ChallengeStatus.woChallenged => AppColors.challengeWo,
      ChallengeStatus.cancelled => AppColors.onBackgroundLight,
      _ => AppColors.challengeWo,
    };

    final winnerName = challenge.winnerId == challenge.challengerId
        ? challengerName
        : challengedName;

    final resultText = switch (challenge.status) {
      ChallengeStatus.completed => challenge.scoreDisplay ?? 'Concluído',
      ChallengeStatus.woChallenger => 'WO $challengerName',
      ChallengeStatus.woChallenged => 'WO $challengedName',
      ChallengeStatus.cancelled => 'Cancelado',
      ChallengeStatus.expired => 'Expirado',
      _ => challenge.statusLabel,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => context.push('/challenges/${challenge.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$challengerName vs $challengedName',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (challenge.winnerId != null) ...[
                          Icon(Icons.emoji_events, color: AppColors.gold, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            winnerName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onBackgroundMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            resultText,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          challenge.createdAt.timeAgo(),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.onBackgroundLight),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (challenge.isFinished)
                LikeButton(challengeId: challenge.id, ref: ref),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, color: AppColors.onBackgroundLight, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChallengeListTile extends ConsumerWidget {
  final ChallengeModel challenge;
  final String currentPlayerId;

  const _ChallengeListTile({
    required this.challenge,
    required this.currentPlayerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isChallenger = challenge.isChallenger(currentPlayerId);
    final opponentName = isChallenger
        ? (challenge.challengedName ?? 'Oponente')
        : (challenge.challengerName ?? 'Oponente');
    final opponentPosition = isChallenger
        ? challenge.challengedPosition
        : challenge.challengerPosition;

    final statusColor = switch (challenge.status) {
      ChallengeStatus.pending => AppColors.challengePending,
      ChallengeStatus.datesProposed => AppColors.challengePending,
      ChallengeStatus.scheduled => AppColors.challengeScheduled,
      ChallengeStatus.completed => AppColors.challengeCompleted,
      _ => AppColors.challengeWo,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => context.push('/challenges/${challenge.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Challenge info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isChallenger ? 'Você desafiou' : 'Desafiado por',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onBackgroundMedium,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$opponentName (#$opponentPosition)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            challenge.scoreDisplay ?? challenge.statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          challenge.createdAt.timeAgo(),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.onBackgroundLight),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Result indicator for finished challenges
              if (challenge.isFinished && challenge.winnerId != null)
                Icon(
                  challenge.didWin(currentPlayerId)
                      ? Icons.emoji_events
                      : Icons.close,
                  color: challenge.didWin(currentPlayerId)
                      ? AppColors.gold
                      : AppColors.error,
                  size: 24,
                ),

              if (challenge.isFinished)
                LikeButton(challengeId: challenge.id, ref: ref),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, color: AppColors.onBackgroundLight, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}


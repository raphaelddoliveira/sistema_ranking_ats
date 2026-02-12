import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/match_model.dart';
import '../viewmodel/challenge_detail_viewmodel.dart';
import '../viewmodel/challenge_list_viewmodel.dart';

class RecordResultScreen extends ConsumerStatefulWidget {
  final String challengeId;
  final String challengerId;
  final String challengedId;
  final String challengerName;
  final String challengedName;

  const RecordResultScreen({
    super.key,
    required this.challengeId,
    required this.challengerId,
    required this.challengedId,
    required this.challengerName,
    required this.challengedName,
  });

  @override
  ConsumerState<RecordResultScreen> createState() =>
      _RecordResultScreenState();
}

class _RecordResultScreenState extends ConsumerState<RecordResultScreen> {
  bool _superTiebreak = false;
  bool _isSubmitting = false;

  // Set scores: up to 3 sets
  final List<_SetScoreInput> _sets = [
    _SetScoreInput(), // Set 1
    _SetScoreInput(), // Set 2
  ];

  /// Determina o vencedor automaticamente a partir do placar dos sets.
  /// Retorna o ID do vencedor, ou null se ainda nao ha vencedor definido.
  String? _determineWinner() {
    int challengerSetsWon = 0;
    int challengedSetsWon = 0;

    for (final set in _sets) {
      if (set.challengerGames != null && set.challengedGames != null) {
        if (set.challengerGames! > set.challengedGames!) {
          challengerSetsWon++;
        } else if (set.challengedGames! > set.challengerGames!) {
          challengedSetsWon++;
        }
        // Empate em games num set = set invalido, nao conta
      }
    }

    if (challengerSetsWon > challengedSetsWon && challengerSetsWon >= 2) {
      return widget.challengerId;
    } else if (challengedSetsWon > challengerSetsWon && challengedSetsWon >= 2) {
      return widget.challengedId;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final winnerId = _determineWinner();
    final winnerName = winnerId == widget.challengerId
        ? widget.challengerName
        : winnerId == widget.challengedId
            ? widget.challengedName
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Resultado'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Set scores
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Placar',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        if (_sets.length < 3)
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _sets.add(_SetScoreInput()));
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('3o Set'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Column headers with player names
                    Row(
                      children: [
                        const SizedBox(width: 60),
                        Expanded(
                          child: Center(
                            child: Text(
                              _firstName(widget.challengerName),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onBackgroundMedium,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              _firstName(widget.challengedName),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onBackgroundMedium,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (_sets.length > 2) const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ...List.generate(_sets.length, (index) {
                      final isLast = index == _sets.length - 1;
                      final set = _sets[index];
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    index == 2 && _superTiebreak
                                        ? 'Tiebreak'
                                        : 'Set ${index + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  child: _ScoreDropdown(
                                    value: set.challengerGames,
                                    isSuperTiebreak:
                                        index == 2 && _superTiebreak,
                                    onChanged: (v) => setState(() {
                                      set.challengerGames = v;
                                      if (!set.isTiebreak) {
                                        set.challengerTiebreak = null;
                                        set.challengedTiebreak = null;
                                      }
                                    }),
                                  ),
                                ),
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('x',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                Expanded(
                                  child: _ScoreDropdown(
                                    value: set.challengedGames,
                                    isSuperTiebreak:
                                        index == 2 && _superTiebreak,
                                    onChanged: (v) => setState(() {
                                      set.challengedGames = v;
                                      if (!set.isTiebreak) {
                                        set.challengerTiebreak = null;
                                        set.challengedTiebreak = null;
                                      }
                                    }),
                                  ),
                                ),
                                if (_sets.length > 2 && isLast)
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _sets.removeLast();
                                        _superTiebreak = false;
                                      });
                                    },
                                    icon: const Icon(Icons.close,
                                        size: 20,
                                        color: AppColors.onBackgroundLight),
                                  )
                                else if (_sets.length > 2)
                                  const SizedBox(width: 40),
                              ],
                            ),
                          ),
                          // Tiebreak score row (aparece quando set é 7-6 ou 6-7)
                          if (set.isTiebreak)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      'TB ${index + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _ScoreDropdown(
                                      value: set.challengerTiebreak,
                                      isTiebreak: true,
                                      onChanged: (v) => setState(
                                          () => set.challengerTiebreak = v),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: Text('x',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ),
                                  Expanded(
                                    child: _ScoreDropdown(
                                      value: set.challengedTiebreak,
                                      isTiebreak: true,
                                      onChanged: (v) => setState(
                                          () => set.challengedTiebreak = v),
                                    ),
                                  ),
                                  if (_sets.length > 2)
                                    const SizedBox(width: 40),
                                ],
                              ),
                            ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Super tiebreak toggle
            if (_sets.length >= 3)
              Card(
                child: SwitchListTile(
                  title: const Text('Super Tiebreak (3o set)'),
                  subtitle: const Text(
                    'Marque se o 3o set foi decidido por super tiebreak (10 pontos)',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _superTiebreak,
                  onChanged: (v) => setState(() => _superTiebreak = v),
                  activeTrackColor: AppColors.primary.withAlpha(100),
                ),
              ),

            const SizedBox(height: 16),

            // Auto-determined winner indicator
            if (winnerId != null)
              Card(
                color: AppColors.success.withAlpha(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.emoji_events,
                          color: AppColors.secondary, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        '$winnerName venceu!',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildScoreString(),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      if (_superTiebreak)
                        const Text(
                          'Super tiebreak',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.onBackgroundLight),
                        ),
                    ],
                  ),
                ),
              )
            else if (_hasAnyScore())
              Card(
                color: AppColors.surfaceVariant,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: AppColors.onBackgroundMedium),
                      SizedBox(width: 8),
                      Text(
                        'Preencha o placar para definir o vencedor',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.onBackgroundMedium),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Submit button
            ElevatedButton.icon(
              onPressed: _canSubmit() && !_isSubmitting ? _submit : null,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(
                  _isSubmitting ? 'Registrando...' : 'Registrar Resultado'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasAnyScore() {
    return _sets.any(
        (s) => s.challengerGames != null || s.challengedGames != null);
  }

  bool _canSubmit() {
    // O vencedor precisa ser determinavel pelo placar
    return _determineWinner() != null;
  }

  String _buildScoreString() {
    final winnerId = _determineWinner();
    return _sets
        .where((s) =>
            s.challengerGames != null && s.challengedGames != null)
        .map((s) {
      final String games;
      final String tb;

      if (winnerId == widget.challengerId) {
        games = '${s.challengerGames}-${s.challengedGames}';
        tb = (s.isTiebreak &&
                s.challengerTiebreak != null &&
                s.challengedTiebreak != null)
            ? '(${s.challengerTiebreak}-${s.challengedTiebreak})'
            : '';
      } else {
        games = '${s.challengedGames}-${s.challengerGames}';
        tb = (s.isTiebreak &&
                s.challengerTiebreak != null &&
                s.challengedTiebreak != null)
            ? '(${s.challengedTiebreak}-${s.challengerTiebreak})'
            : '';
      }
      return '$games$tb';
    }).join(' ');
  }

  String _firstName(String fullName) {
    return fullName.split(' ').first;
  }

  Future<void> _submit() async {
    final winnerId = _determineWinner();
    if (winnerId == null) return;

    final loserId = winnerId == widget.challengerId
        ? widget.challengedId
        : widget.challengerId;

    // Build sets - mapear de challenger/challenged para winner/loser
    final validSets = <SetScore>[];
    int winnerSets = 0;
    int loserSets = 0;

    for (final set in _sets) {
      if (set.challengerGames != null && set.challengedGames != null) {
        final int wGames;
        final int lGames;

        if (winnerId == widget.challengerId) {
          wGames = set.challengerGames!;
          lGames = set.challengedGames!;
        } else {
          wGames = set.challengedGames!;
          lGames = set.challengerGames!;
        }

        // Mapear tiebreak scores para winner/loser
        int? tbWinner;
        int? tbLoser;
        if (set.isTiebreak &&
            set.challengerTiebreak != null &&
            set.challengedTiebreak != null) {
          if (winnerId == widget.challengerId) {
            tbWinner = set.challengerTiebreak;
            tbLoser = set.challengedTiebreak;
          } else {
            tbWinner = set.challengedTiebreak;
            tbLoser = set.challengerTiebreak;
          }
        }

        validSets.add(SetScore(
          winnerGames: wGames,
          loserGames: lGames,
          tiebreakWinner: tbWinner,
          tiebreakLoser: tbLoser,
        ));

        if (wGames > lGames) {
          winnerSets++;
        } else {
          loserSets++;
        }
      }
    }

    setState(() => _isSubmitting = true);

    final success =
        await ref.read(challengeActionProvider.notifier).recordResult(
              challengeId: widget.challengeId,
              winnerId: winnerId,
              loserId: loserId,
              sets: validSets,
              winnerSets: winnerSets,
              loserSets: loserSets,
              superTiebreak: _superTiebreak,
            );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      SnackbarUtils.showSuccess(context, 'Resultado registrado!');
      ref.invalidate(challengeDetailProvider(widget.challengeId));
      ref.invalidate(challengeMatchProvider(widget.challengeId));
      ref.invalidate(activeChallengesProvider);
      ref.invalidate(challengeHistoryProvider);
      context.pop();
    } else {
      SnackbarUtils.showError(context, 'Erro ao registrar resultado');
    }
  }
}

class _SetScoreInput {
  int? challengerGames;
  int? challengedGames;
  int? challengerTiebreak;
  int? challengedTiebreak;

  bool get isTiebreak {
    if (challengerGames == null || challengedGames == null) return false;
    return (challengerGames == 7 && challengedGames == 6) ||
        (challengerGames == 6 && challengedGames == 7);
  }
}

class _ScoreDropdown extends StatelessWidget {
  final int? value;
  final bool isSuperTiebreak;
  final bool isTiebreak;
  final ValueChanged<int?> onChanged;

  const _ScoreDropdown({
    required this.value,
    this.isSuperTiebreak = false,
    this.isTiebreak = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final int count;
    if (isSuperTiebreak) {
      count = 21; // 0-20 for super tiebreak
    } else if (isTiebreak) {
      count = 21; // 0-20 for regular tiebreak
    } else {
      count = 8; // 0-7 for regular games
    }
    final items = List.generate(count, (i) => i);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isTiebreak ? AppColors.primary.withAlpha(80) : AppColors.divider,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          hint: const Center(child: Text('-')),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          items: items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Center(
                      child: Text(
                        '$i',
                        style: TextStyle(
                          fontSize: isTiebreak ? 15 : 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

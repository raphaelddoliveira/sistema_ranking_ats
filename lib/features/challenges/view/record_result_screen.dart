import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String? _winnerId;
  bool _superTiebreak = false;
  bool _isSubmitting = false;

  // Set scores: up to 3 sets
  final List<_SetScoreInput> _sets = [
    _SetScoreInput(), // Set 1
    _SetScoreInput(), // Set 2
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Resultado'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Winner selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quem venceu?',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _WinnerOption(
                      name: widget.challengerName,
                      label: 'Desafiante',
                      isSelected: _winnerId == widget.challengerId,
                      onTap: () =>
                          setState(() => _winnerId = widget.challengerId),
                    ),
                    const SizedBox(height: 8),
                    _WinnerOption(
                      name: widget.challengedName,
                      label: 'Desafiado',
                      isSelected: _winnerId == widget.challengedId,
                      onTap: () =>
                          setState(() => _winnerId = widget.challengedId),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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

                    // Column headers
                    Row(
                      children: [
                        const SizedBox(width: 60),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Vencedor',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Perdedor',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (_sets.length > 2) const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ...List.generate(_sets.length, (index) {
                      final isLast = index == _sets.length - 1;
                      return Padding(
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
                                value: _sets[index].winnerGames,
                                isSuperTiebreak:
                                    index == 2 && _superTiebreak,
                                onChanged: (v) => setState(
                                    () => _sets[index].winnerGames = v),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('x',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              child: _ScoreDropdown(
                                value: _sets[index].loserGames,
                                isSuperTiebreak:
                                    index == 2 && _superTiebreak,
                                onChanged: (v) => setState(
                                    () => _sets[index].loserGames = v),
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
                                    size: 20, color: Colors.grey),
                              )
                            else if (_sets.length > 2)
                              const SizedBox(width: 40),
                          ],
                        ),
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

            const SizedBox(height: 24),

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

            const SizedBox(height: 8),

            // Preview
            if (_winnerId != null && _canSubmit()) _buildPreview(),
          ],
        ),
      ),
    );
  }

  bool _canSubmit() {
    if (_winnerId == null) return false;

    // At least 2 sets must have scores
    int completeSets = 0;
    for (final set in _sets) {
      if (set.winnerGames != null && set.loserGames != null) {
        completeSets++;
      }
    }
    return completeSets >= 2;
  }

  Widget _buildPreview() {
    final winnerName = _winnerId == widget.challengerId
        ? widget.challengerName
        : widget.challengedName;

    final scores = _sets
        .where((s) => s.winnerGames != null && s.loserGames != null)
        .map((s) => '${s.winnerGames}-${s.loserGames}')
        .join(' ');

    return Card(
      color: AppColors.success.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Resultado',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              '$winnerName venceu',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              scores,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600),
            ),
            if (_superTiebreak)
              const Text(
                'Super tiebreak',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_winnerId == null) return;

    final loserId = _winnerId == widget.challengerId
        ? widget.challengedId
        : widget.challengerId;

    // Build sets
    final validSets = <SetScore>[];
    int winnerSets = 0;
    int loserSets = 0;

    for (final set in _sets) {
      if (set.winnerGames != null && set.loserGames != null) {
        validSets.add(SetScore(
          winnerGames: set.winnerGames!,
          loserGames: set.loserGames!,
        ));
        if (set.winnerGames! > set.loserGames!) {
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
              winnerId: _winnerId!,
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
      Navigator.of(context).pop();
    } else {
      SnackbarUtils.showError(context, 'Erro ao registrar resultado');
    }
  }
}

class _SetScoreInput {
  int? winnerGames;
  int? loserGames;
}

class _WinnerOption extends StatelessWidget {
  final String name;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _WinnerOption({
    required this.name,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? AppColors.primary.withAlpha(15) : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : null,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.emoji_events,
                  color: AppColors.secondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ScoreDropdown extends StatelessWidget {
  final int? value;
  final bool isSuperTiebreak;
  final ValueChanged<int?> onChanged;

  const _ScoreDropdown({
    required this.value,
    this.isSuperTiebreak = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = isSuperTiebreak
        ? List.generate(14, (i) => i) // 0-13 for super tiebreak
        : List.generate(8, (i) => i); // 0-7 for regular games

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
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
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
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

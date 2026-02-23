import 'match_model.dart';

class H2HModel {
  final String player1Id;
  final String player2Id;
  final String? player1Name;
  final String? player2Name;
  final int player1Wins;
  final int player2Wins;
  final int player1Sets;
  final int player2Sets;
  final int player1WOs;
  final int player2WOs;
  final List<H2HMatch> matches;

  const H2HModel({
    required this.player1Id,
    required this.player2Id,
    this.player1Name,
    this.player2Name,
    required this.player1Wins,
    required this.player2Wins,
    required this.player1Sets,
    required this.player2Sets,
    required this.player1WOs,
    required this.player2WOs,
    required this.matches,
  });

  int get totalMatches => player1Wins + player2Wins;
  bool get isEmpty => totalMatches == 0;
  H2HMatch? get lastMatch => matches.isNotEmpty ? matches.first : null;

  /// Build from raw challenge+match query results
  factory H2HModel.fromQueryResults({
    required String player1Id,
    required String player2Id,
    String? player1Name,
    String? player2Name,
    required List<Map<String, dynamic>> rows,
  }) {
    int p1Wins = 0, p2Wins = 0;
    int p1Sets = 0, p2Sets = 0;
    int p1WOs = 0, p2WOs = 0;
    final matchList = <H2HMatch>[];

    for (final row in rows) {
      final winnerId = row['winner_id'] as String?;
      final loserId = row['loser_id'] as String?;
      final status = row['status'] as String;
      final isWO = status == 'wo_challenger' || status == 'wo_challenged';

      if (winnerId == null) continue;

      if (winnerId == player1Id) {
        p1Wins++;
      } else {
        p2Wins++;
      }

      if (isWO) {
        if (loserId == player1Id) p1WOs++;
        if (loserId == player2Id) p2WOs++;
      }

      // Parse match data if available
      final matchData = row['match'] as Map<String, dynamic>?;
      int winnerSets = 0, loserSets = 0;
      String? scoreDisplay;

      if (matchData != null) {
        winnerSets = matchData['winner_sets'] as int? ?? 0;
        loserSets = matchData['loser_sets'] as int? ?? 0;
        final setsJson = matchData['sets'] as List<dynamic>? ?? [];
        final sets = setsJson
            .map((s) => SetScore.fromJson(s as Map<String, dynamic>))
            .toList();
        scoreDisplay = sets.map((s) => s.display).join(' ');

        // Accumulate sets
        if (winnerId == player1Id) {
          p1Sets += winnerSets;
          p2Sets += loserSets;
        } else {
          p2Sets += winnerSets;
          p1Sets += loserSets;
        }
      }

      matchList.add(H2HMatch(
        challengeId: row['id'] as String,
        winnerId: winnerId,
        loserId: loserId ?? '',
        scoreDisplay: scoreDisplay,
        winnerSets: winnerSets,
        loserSets: loserSets,
        isWO: isWO,
        playedAt: DateTime.parse(
          (row['completed_at'] ?? row['created_at']) as String,
        ),
      ));
    }

    return H2HModel(
      player1Id: player1Id,
      player2Id: player2Id,
      player1Name: player1Name,
      player2Name: player2Name,
      player1Wins: p1Wins,
      player2Wins: p2Wins,
      player1Sets: p1Sets,
      player2Sets: p2Sets,
      player1WOs: p1WOs,
      player2WOs: p2WOs,
      matches: matchList,
    );
  }
}

class H2HMatch {
  final String challengeId;
  final String winnerId;
  final String loserId;
  final String? scoreDisplay;
  final int winnerSets;
  final int loserSets;
  final bool isWO;
  final DateTime playedAt;

  const H2HMatch({
    required this.challengeId,
    required this.winnerId,
    required this.loserId,
    this.scoreDisplay,
    required this.winnerSets,
    required this.loserSets,
    required this.isWO,
    required this.playedAt,
  });

  String get resultDisplay {
    if (isWO) return 'WO';
    return scoreDisplay ?? '${winnerSets}x$loserSets';
  }
}

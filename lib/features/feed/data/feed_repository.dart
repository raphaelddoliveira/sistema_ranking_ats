import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/challenge_model.dart';

// --- Feed Item Models ---

sealed class FeedItem {
  DateTime get timestamp;
}

class MatchResultFeedItem extends FeedItem {
  final ChallengeModel challenge;
  final int? winnerOldPos;
  final int? winnerNewPos;
  final int? loserOldPos;
  final int? loserNewPos;

  MatchResultFeedItem({
    required this.challenge,
    this.winnerOldPos,
    this.winnerNewPos,
    this.loserOldPos,
    this.loserNewPos,
  });

  @override
  DateTime get timestamp => challenge.completedAt ?? challenge.updatedAt;

  int? get winnerDelta =>
      (winnerOldPos != null && winnerNewPos != null) ? winnerOldPos! - winnerNewPos! : null;

  int? get loserDelta =>
      (loserOldPos != null && loserNewPos != null) ? loserOldPos! - loserNewPos! : null;
}

class NewMemberFeedItem extends FeedItem {
  final String playerId;
  final String playerName;
  final String? avatarUrl;
  final int? rankingPosition;
  final DateTime joinedAt;

  NewMemberFeedItem({
    required this.playerId,
    required this.playerName,
    this.avatarUrl,
    this.rankingPosition,
    required this.joinedAt,
  });

  @override
  DateTime get timestamp => joinedAt;
}

// --- Repository ---

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(supabaseClientProvider));
});

class FeedRepository {
  final SupabaseClient _client;

  FeedRepository(this._client);

  static const _selectWithJoins = '''
    *,
    challenger:players!challenger_id(full_name, avatar_url),
    challenged:players!challenged_id(full_name, avatar_url),
    court:courts!court_id(name),
    match:matches!challenge_id(winner_id, loser_id, winner_sets, loser_sets, sets)
  ''';

  Future<List<FeedItem>> getFeed({
    required String clubId,
    String? sportId,
    int limit = 30,
  }) async {
    try {
      // 1. Fetch completed/WO challenges
      var query = _client
          .from(SupabaseConstants.challengesTable)
          .select(_selectWithJoins)
          .eq('club_id', clubId)
          .inFilter('status', ['completed', 'wo_challenger', 'wo_challenged']);
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }
      final challengeData = await query
          .order('completed_at', ascending: false)
          .limit(limit);

      final challenges = challengeData
          .map((e) => ChallengeModel.fromJson(e))
          .toList();

      // 2. Batch fetch ranking_history for these challenges
      final challengeIds = challenges.map((c) => c.id).toList();
      Map<String, List<Map<String, dynamic>>> rankingByChallenge = {};

      if (challengeIds.isNotEmpty) {
        final rankingData = await _client
            .from(SupabaseConstants.rankingHistoryTable)
            .select('player_id, old_position, new_position, reference_id')
            .inFilter('reference_id', challengeIds)
            .inFilter('reason', ['challenge_win', 'challenge_loss']);

        for (final r in rankingData) {
          final refId = r['reference_id'] as String;
          rankingByChallenge.putIfAbsent(refId, () => []).add(r);
        }
      }

      // 3. Build match result feed items
      final List<FeedItem> items = [];
      for (final challenge in challenges) {
        final rankings = rankingByChallenge[challenge.id] ?? [];

        int? winnerOldPos, winnerNewPos, loserOldPos, loserNewPos;
        for (final r in rankings) {
          final playerId = r['player_id'] as String;
          if (playerId == challenge.winnerId) {
            winnerOldPos = r['old_position'] as int?;
            winnerNewPos = r['new_position'] as int?;
          } else if (playerId == challenge.loserId) {
            loserOldPos = r['old_position'] as int?;
            loserNewPos = r['new_position'] as int?;
          }
        }

        items.add(MatchResultFeedItem(
          challenge: challenge,
          winnerOldPos: winnerOldPos,
          winnerNewPos: winnerNewPos,
          loserOldPos: loserOldPos,
          loserNewPos: loserNewPos,
        ));
      }

      // 4. Fetch new members (last 30 days)
      final thirtyDaysAgo = DateTime.now()
          .subtract(const Duration(days: 30))
          .toUtc()
          .toIso8601String();

      var membersQuery = _client
          .from(SupabaseConstants.clubMembersTable)
          .select('player_id, ranking_position, joined_at, player:players(full_name, avatar_url)')
          .eq('club_id', clubId)
          .eq('status', 'active')
          .eq('ranking_opt_in', true)
          .not('ranking_position', 'is', null)
          .gte('joined_at', thirtyDaysAgo);
      if (sportId != null) {
        membersQuery = membersQuery.eq('sport_id', sportId);
      }
      final membersData = await membersQuery
          .order('joined_at', ascending: false)
          .limit(10);

      for (final m in membersData) {
        final player = m['player'] as Map<String, dynamic>?;
        items.add(NewMemberFeedItem(
          playerId: m['player_id'] as String,
          playerName: player?['full_name'] as String? ?? 'Jogador',
          avatarUrl: player?['avatar_url'] as String?,
          rankingPosition: m['ranking_position'] as int?,
          joinedAt: DateTime.parse(m['joined_at'] as String),
        ));
      }

      // 5. Sort by timestamp descending
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return items;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}

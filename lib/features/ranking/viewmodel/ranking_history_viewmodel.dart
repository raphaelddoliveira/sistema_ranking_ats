import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/ranking_history_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../data/ranking_repository.dart';
import 'ranking_list_viewmodel.dart';

final rankingHistoryProvider =
    FutureProvider.family<List<RankingHistoryModel>, String>(
        (ref, playerId) async {
  final clubId = ref.watch(currentClubIdProvider);
  final repository = ref.watch(rankingRepositoryProvider);
  return repository.getPlayerHistory(playerId, clubId: clubId);
});

/// Get a player's club membership details (for ranking history screen)
final playerClubMemberProvider =
    FutureProvider.family<ClubMemberModel?, String>((ref, playerId) async {
  final clubId = ref.watch(currentClubIdProvider);
  if (clubId == null) return null;
  final ranking = ref.watch(rankingListProvider);
  final members = ranking.valueOrNull ?? [];
  try {
    return members.firstWhere((m) => m.playerId == playerId);
  } catch (_) {
    return null;
  }
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/player_model.dart';
import '../../../shared/models/ranking_history_model.dart';
import '../data/ranking_repository.dart';

final rankingHistoryProvider =
    FutureProvider.family<List<RankingHistoryModel>, String>(
        (ref, playerId) async {
  final repository = ref.watch(rankingRepositoryProvider);
  return repository.getPlayerHistory(playerId);
});

final playerDetailProvider =
    FutureProvider.family<PlayerModel, String>((ref, playerId) async {
  final repository = ref.watch(rankingRepositoryProvider);
  return repository.getPlayer(playerId);
});

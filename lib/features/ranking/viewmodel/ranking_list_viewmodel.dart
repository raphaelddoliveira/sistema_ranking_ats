import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/player_model.dart';
import '../data/ranking_repository.dart';

final rankingStreamProvider = StreamProvider<List<PlayerModel>>((ref) {
  final repository = ref.watch(rankingRepositoryProvider);
  return repository.getRankingStream();
});

final rankingListProvider =
    FutureProvider<List<PlayerModel>>((ref) async {
  final repository = ref.watch(rankingRepositoryProvider);
  return repository.getRanking();
});

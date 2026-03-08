import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/current_player_provider.dart';
import '../data/challenge_like_repository.dart';

/// Provider for like status of a single challenge
final challengeLikeProvider = FutureProvider.family<({int count, bool liked}), String>(
  (ref, challengeId) async {
    final player = ref.watch(currentPlayerProvider).valueOrNull;
    if (player == null) return (count: 0, liked: false);
    final repo = ref.watch(challengeLikeRepositoryProvider);
    return repo.getLikeStatus(challengeId, player.id);
  },
);

/// Provider for bulk like status (used in lists)
final bulkChallengeLikesProvider = FutureProvider.family<
    Map<String, ({int count, bool liked})>, List<String>>(
  (ref, challengeIds) async {
    final player = ref.watch(currentPlayerProvider).valueOrNull;
    if (player == null) return {};
    final repo = ref.watch(challengeLikeRepositoryProvider);
    return repo.getBulkLikeStatus(challengeIds, player.id);
  },
);

/// Action notifier for toggling likes
final challengeLikeActionProvider =
    StateNotifierProvider<ChallengeLikeActionNotifier, AsyncValue<void>>((ref) {
  return ChallengeLikeActionNotifier(ref);
});

class ChallengeLikeActionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ChallengeLikeActionNotifier(this._ref) : super(const AsyncData(null));

  Future<void> toggleLike(String challengeId) async {
    final player = _ref.read(currentPlayerProvider).valueOrNull;
    if (player == null) return;
    final repo = _ref.read(challengeLikeRepositoryProvider);
    await repo.toggleLike(challengeId, player.id);
    _ref.invalidate(challengeLikeProvider(challengeId));
  }
}

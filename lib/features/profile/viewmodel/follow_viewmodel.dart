import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/current_player_provider.dart';
import '../data/follow_repository.dart';

/// Whether current player follows a specific player
final isFollowingProvider = FutureProvider.family<bool, String>(
  (ref, playerId) async {
    final currentPlayer = ref.watch(currentPlayerProvider).valueOrNull;
    if (currentPlayer == null) return false;
    final repo = ref.watch(followRepositoryProvider);
    return repo.isFollowing(currentPlayer.id, playerId);
  },
);

/// Follow counts for a specific player
final followCountsProvider = FutureProvider.family<({int followers, int following}), String>(
  (ref, playerId) async {
    final repo = ref.watch(followRepositoryProvider);
    return repo.getFollowCounts(playerId);
  },
);

/// Action notifier for follow/unfollow
final followActionProvider =
    StateNotifierProvider<FollowActionNotifier, AsyncValue<void>>((ref) {
  return FollowActionNotifier(ref);
});

class FollowActionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  bool _busy = false;

  FollowActionNotifier(this._ref) : super(const AsyncData(null));

  Future<void> toggleFollow(String targetPlayerId) async {
    if (_busy) return;
    _busy = true;
    state = const AsyncLoading();
    try {
      final currentPlayer = _ref.read(currentPlayerProvider).valueOrNull;
      if (currentPlayer == null) {
        state = const AsyncData(null);
        _busy = false;
        return;
      }
      final repo = _ref.read(followRepositoryProvider);
      await repo.toggleFollow(currentPlayer.id, targetPlayerId);
      _ref.invalidate(isFollowingProvider(targetPlayerId));
      _ref.invalidate(followCountsProvider(targetPlayerId));
      _ref.invalidate(followCountsProvider(currentPlayer.id));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    } finally {
      _busy = false;
    }
  }
}

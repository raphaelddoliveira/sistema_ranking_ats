import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../services/supabase_service.dart';

final challengeLikeRepositoryProvider = Provider<ChallengeLikeRepository>((ref) {
  return ChallengeLikeRepository(ref.watch(supabaseClientProvider));
});

class ChallengeLikeRepository {
  final SupabaseClient _client;

  ChallengeLikeRepository(this._client);

  /// Get like count and whether current player liked a challenge
  Future<({int count, bool liked})> getLikeStatus(String challengeId, String playerId) async {
    try {
      final data = await _client
          .from('challenge_likes')
          .select('id, player_id')
          .eq('challenge_id', challengeId);
      final count = data.length;
      final liked = data.any((e) => e['player_id'] == playerId);
      return (count: count, liked: liked);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get like counts and liked status for multiple challenges at once
  Future<Map<String, ({int count, bool liked})>> getBulkLikeStatus(
    List<String> challengeIds,
    String playerId,
  ) async {
    if (challengeIds.isEmpty) return {};
    try {
      final data = await _client
          .from('challenge_likes')
          .select('challenge_id, player_id')
          .inFilter('challenge_id', challengeIds);

      final result = <String, ({int count, bool liked})>{};
      for (final id in challengeIds) {
        final likes = data.where((e) => e['challenge_id'] == id);
        result[id] = (
          count: likes.length,
          liked: likes.any((e) => e['player_id'] == playerId),
        );
      }
      return result;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Toggle like on a challenge
  Future<bool> toggleLike(String challengeId, String playerId) async {
    try {
      // Check if already liked
      final existing = await _client
          .from('challenge_likes')
          .select('id')
          .eq('challenge_id', challengeId)
          .eq('player_id', playerId)
          .maybeSingle();

      if (existing != null) {
        // Unlike
        await _client
            .from('challenge_likes')
            .delete()
            .eq('challenge_id', challengeId)
            .eq('player_id', playerId);
        return false;
      } else {
        // Like
        await _client.from('challenge_likes').insert({
          'challenge_id': challengeId,
          'player_id': playerId,
        });
        return true;
      }
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}

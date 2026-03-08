import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../services/supabase_service.dart';

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository(ref.watch(supabaseClientProvider));
});

class FollowRepository {
  final SupabaseClient _client;

  FollowRepository(this._client);

  /// Check if current player follows another player
  Future<bool> isFollowing(String followerId, String followedId) async {
    try {
      final data = await _client
          .from('follows')
          .select('id')
          .eq('follower_id', followerId)
          .eq('followed_id', followedId)
          .maybeSingle();
      return data != null;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get follower and following counts for a player
  Future<({int followers, int following})> getFollowCounts(String playerId) async {
    try {
      final followers = await _client
          .from('follows')
          .select('id')
          .eq('followed_id', playerId);
      final following = await _client
          .from('follows')
          .select('id')
          .eq('follower_id', playerId);
      return (followers: followers.length, following: following.length);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Follow a player
  Future<void> follow(String followerId, String followedId) async {
    try {
      await _client.from('follows').insert({
        'follower_id': followerId,
        'followed_id': followedId,
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Unfollow a player
  Future<void> unfollow(String followerId, String followedId) async {
    try {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('followed_id', followedId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Toggle follow/unfollow
  Future<bool> toggleFollow(String followerId, String followedId) async {
    final following = await isFollowing(followerId, followedId);
    if (following) {
      await unfollow(followerId, followedId);
      return false;
    } else {
      await follow(followerId, followedId);
      return true;
    }
  }
}

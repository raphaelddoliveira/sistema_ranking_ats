import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/player_model.dart';
import '../../../shared/models/ranking_history_model.dart';

final rankingRepositoryProvider = Provider<RankingRepository>((ref) {
  return RankingRepository(ref.watch(supabaseClientProvider));
});

class RankingRepository {
  final SupabaseClient _client;

  RankingRepository(this._client);

  Future<List<PlayerModel>> getRanking() async {
    try {
      final data = await _client
          .from(SupabaseConstants.playersTable)
          .select()
          .neq('status', 'inactive')
          .not('ranking_position', 'is', null)
          .order('ranking_position');
      return data.map((e) => PlayerModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Stream<List<PlayerModel>> getRankingStream() {
    return _client
        .from(SupabaseConstants.playersTable)
        .stream(primaryKey: ['id'])
        .order('ranking_position')
        .map((data) => data
            .where((e) =>
                e['status'] != 'inactive' && e['ranking_position'] != null)
            .map((e) => PlayerModel.fromJson(e))
            .toList());
  }

  Future<List<RankingHistoryModel>> getPlayerHistory(
    String playerId, {
    int limit = 50,
  }) async {
    try {
      final data = await _client
          .from(SupabaseConstants.rankingHistoryTable)
          .select()
          .eq('player_id', playerId)
          .order('created_at', ascending: false)
          .limit(limit);
      return data.map((e) => RankingHistoryModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<PlayerModel> getPlayer(String playerId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.playersTable)
          .select()
          .eq('id', playerId)
          .single();
      return PlayerModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}

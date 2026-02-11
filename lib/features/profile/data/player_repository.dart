import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../../../services/storage_service.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/player_model.dart';

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(storageServiceProvider),
  );
});

class PlayerRepository {
  final SupabaseClient _client;
  final StorageService _storageService;

  PlayerRepository(this._client, this._storageService);

  Future<PlayerModel> getPlayer(String id) async {
    try {
      final data = await _client
          .from(SupabaseConstants.playersTable)
          .select()
          .eq('id', id)
          .single();
      return PlayerModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<List<PlayerModel>> getAllPlayers() async {
    try {
      final data = await _client
          .from(SupabaseConstants.playersTable)
          .select()
          .neq('status', 'inactive')
          .order('ranking_position');
      return data.map((e) => PlayerModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<PlayerModel> updatePlayer(String id, PlayerModel player) async {
    try {
      final data = await _client
          .from(SupabaseConstants.playersTable)
          .update(player.toUpdateJson())
          .eq('id', id)
          .select()
          .single();
      return PlayerModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<String> updateAvatar(String playerId, XFile file) async {
    try {
      final url = await _storageService.uploadAvatar(playerId, file);

      await _client
          .from(SupabaseConstants.playersTable)
          .update({'avatar_url': url}).eq('id', playerId);

      return url;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}

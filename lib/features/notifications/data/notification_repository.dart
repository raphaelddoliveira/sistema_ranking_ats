import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/notification_model.dart';

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

class NotificationRepository {
  final SupabaseClient _client;

  NotificationRepository(this._client);

  /// Get all notifications for current player
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final playerId = await _getCurrentPlayerId();
      final data = await _client
          .from(SupabaseConstants.notificationsTable)
          .select()
          .eq('player_id', playerId)
          .order('created_at', ascending: false)
          .limit(100);
      return data.map((e) => NotificationModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    try {
      final playerId = await _getCurrentPlayerId();
      final data = await _client
          .from(SupabaseConstants.notificationsTable)
          .select('id')
          .eq('player_id', playerId)
          .eq('is_read', false);
      return data.length;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from(SupabaseConstants.notificationsTable)
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Mark all as read
  Future<void> markAllAsRead() async {
    try {
      final playerId = await _getCurrentPlayerId();
      await _client
          .from(SupabaseConstants.notificationsTable)
          .update({'is_read': true})
          .eq('player_id', playerId)
          .eq('is_read', false);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Stream notifications for Realtime updates
  Stream<List<Map<String, dynamic>>> notificationsStream() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _client
        .from(SupabaseConstants.notificationsTable)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(100);
  }

  Future<String> _getCurrentPlayerId() async {
    final authId = _client.auth.currentUser!.id;
    final data = await _client
        .from(SupabaseConstants.playersTable)
        .select('id')
        .eq('auth_id', authId)
        .single();
    return data['id'] as String;
  }
}

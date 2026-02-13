import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/notification_model.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../../services/supabase_service.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../data/notification_repository.dart';

/// Provider for all notifications (filtered by club if selected)
final notificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getNotifications(clubId: clubId);
});

/// Provider for unread count (used in badge)
final unreadCountProvider = FutureProvider<int>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUnreadCount(clubId: clubId);
});

/// Realtime listener that auto-refreshes notifications when new ones arrive
final notificationRealtimeProvider = Provider<void>((ref) {
  final player = ref.watch(currentPlayerProvider).valueOrNull;
  if (player == null) return;

  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('notifications_${player.id}');

  channel.onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'notifications',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'player_id',
      value: player.id,
    ),
    callback: (payload) {
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
    },
  ).subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});

/// Action notifier for mark as read operations
final notificationActionProvider =
    StateNotifierProvider<NotificationActionNotifier, AsyncValue<void>>((ref) {
  return NotificationActionNotifier(ref.watch(notificationRepositoryProvider));
});

class NotificationActionNotifier extends StateNotifier<AsyncValue<void>> {
  final NotificationRepository _repository;

  NotificationActionNotifier(this._repository)
      : super(const AsyncData(null));

  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
      state = const AsyncData(null);
    } catch (_) {
      // Silent fail for mark as read
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();
      state = const AsyncData(null);
    } catch (_) {
      // Silent fail
    }
  }
}

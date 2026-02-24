import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/notification_model.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../../services/supabase_service.dart';
import '../../challenges/viewmodel/challenge_list_viewmodel.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../../courts/viewmodel/reservation_viewmodel.dart';
import '../../ranking/viewmodel/ranking_list_viewmodel.dart';
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

/// Realtime listener that auto-refreshes data when notifications arrive
/// or when challenges change status
final notificationRealtimeProvider = Provider<void>((ref) {
  final player = ref.watch(currentPlayerProvider).valueOrNull;
  if (player == null) return;

  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('realtime_${player.id}');

  // Listen for new notifications → refresh notifications + related data
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
      // Also refresh data that might have changed alongside the notification
      ref.invalidate(activeChallengesProvider);
      ref.invalidate(challengeHistoryProvider);
      ref.invalidate(rankingListProvider);
      ref.invalidate(currentClubMemberProvider);
      ref.invalidate(myReservationsProvider);
    },
  );

  // Listen for challenge updates where player is challenger
  channel.onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'challenges',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'challenger_id',
      value: player.id,
    ),
    callback: (payload) {
      ref.invalidate(activeChallengesProvider);
      ref.invalidate(challengeHistoryProvider);
    },
  );

  // Listen for challenge updates where player is challenged
  channel.onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'challenges',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'challenged_id',
      value: player.id,
    ),
    callback: (payload) {
      ref.invalidate(activeChallengesProvider);
      ref.invalidate(challengeHistoryProvider);
    },
  );

  // Listen for ranking changes (club_members updates for this player)
  channel.onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'club_members',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'player_id',
      value: player.id,
    ),
    callback: (payload) {
      ref.invalidate(rankingListProvider);
      ref.invalidate(currentClubMemberProvider);
    },
  );

  channel.subscribe();

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

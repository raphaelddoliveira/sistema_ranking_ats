import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/notification_model.dart';
import '../data/notification_repository.dart';

/// Provider for all notifications
final notificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getNotifications();
});

/// Provider for unread count (used in badge)
final unreadCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUnreadCount();
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

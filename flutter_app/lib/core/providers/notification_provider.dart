// lib/core/providers/notification_provider.dart
//
// State management untuk riwayat notifikasi sistem menggunakan Cloud Firestore.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification_model.dart';
import '../../data/services/firestore_service.dart';
import 'schedule_provider.dart';

// State gabungan: list notifikasi dan jumlah yang belum dibaca.
class NotificationState {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return NotificationNotifier(service);
});

class NotificationNotifier extends StateNotifier<NotificationState> {
  final FirestoreService _firestore;
  StreamSubscription? _subscription;

  NotificationNotifier(this._firestore) : super(const NotificationState(isLoading: true)) {
    loadNotifications();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Memulai sinkronisasi data real-time dengan Cloud Firestore.
  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    _subscription?.cancel();
    _subscription = _firestore.watchNotifications().listen(
      (notifications) {
        final unreadCount = notifications.where((n) => !n.isRead).length;
        state = NotificationState(
          notifications: notifications,
          unreadCount: unreadCount,
          isLoading: false,
        );
      },
      onError: (err, stack) {
        state = state.copyWith(isLoading: false, error: err.toString());
      },
    );
  }

  /// Menandai satu notifikasi sebagai sudah dibaca.
  Future<void> markRead(dynamic id) async {
    String? firestoreId;
    if (id is String) {
      firestoreId = id;
    } else if (id is int) {
      for (final n in state.notifications) {
        if (n.id == id) {
          firestoreId = n.firestoreId;
          break;
        }
      }
    }
    if (firestoreId != null) {
      await _firestore.markNotificationRead(firestoreId);
    }
  }

  /// Menandai semua notifikasi sebagai sudah dibaca.
  Future<void> markAllRead() async {
    await _firestore.markAllNotificationsRead();
  }
}


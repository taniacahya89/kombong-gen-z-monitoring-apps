// lib/core/providers/notification_provider.dart
//
// State management untuk riwayat notifikasi sistem.
//
// Provider:
//   - notificationProvider: StateNotifierProvider yang menyimpan daftar
//     notifikasi dan mendukung operasi mark-as-read (individual & bulk).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification_model.dart';
import '../../data/services/api_service.dart';
import 'auth_provider.dart';

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
  final service = ref.watch(authServiceProvider);
  return NotificationNotifier(service);
});

class NotificationNotifier extends StateNotifier<NotificationState> {
  final ApiService _api;

  NotificationNotifier(this._api) : super(const NotificationState(isLoading: true)) {
    loadNotifications();
  }

  /// Mengambil daftar notifikasi dari backend.
  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _api.getNotifications();
      state = NotificationState(
        notifications: result['notifications'] as List<NotificationModel>,
        // Backend mengembalikan -1 jika query count gagal. Normalize ke 0
        // agar UI tidak menampilkan badge dengan angka negatif.
        unreadCount: ((result['unread_count'] as int?) ?? 0).clamp(0, 9999),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Menandai satu notifikasi sebagai sudah dibaca dan memperbarui state lokal.
  Future<void> markRead(int id) async {
    try {
      await _api.markNotificationRead(id);
      final updated = state.notifications.map((n) {
        return n.id == id ? n.copyWith(isRead: true) : n;
      }).toList();
      final newUnread = updated.where((n) => !n.isRead).length;
      state = state.copyWith(notifications: updated, unreadCount: newUnread);
    } catch (_) {}
  }

  /// Menandai semua notifikasi sebagai sudah dibaca.
  Future<void> markAllRead() async {
    try {
      await _api.markAllNotificationsRead();
      final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
      state = state.copyWith(notifications: updated, unreadCount: 0);
    } catch (_) {}
  }
}

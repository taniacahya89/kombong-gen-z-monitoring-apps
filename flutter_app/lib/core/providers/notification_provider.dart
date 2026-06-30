// lib/core/providers/notification_provider.dart
//
// State management untuk riwayat notifikasi sistem menggunakan Cloud Firestore.

import 'dart:async';
import 'package:flutter/foundation.dart';
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
  Timer? _syncTimer;

  NotificationNotifier(this._firestore) : super(const NotificationState(isLoading: true)) {
    loadNotifications();
    // Jalankan sinkronisasi periodik setiap 30 detik untuk mendeteksi waktu pakan yang baru tiba
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.notifications.isNotEmpty && !state.isLoading) {
        _syncMissedNotifications(state.notifications);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _syncTimer?.cancel();
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
        _syncMissedNotifications(notifications);
      },
      onError: (err, stack) {
        state = state.copyWith(isLoading: false, error: err.toString());
      },
    );
  }

  /// Sinkronisasi jadwal pakan yang terlewat untuk dicatat di Firestore.
  Future<void> _syncMissedNotifications(List<NotificationModel> existing) async {
    try {
      final now = DateTime.now();
      DateTime lastNotifTime;
      final feedingNotifs = existing.where((n) => n.title.contains('Pakan')).toList();
      if (feedingNotifs.isNotEmpty) {
        lastNotifTime = feedingNotifs.first.createdAt;
      } else {
        lastNotifTime = now.subtract(const Duration(hours: 12));
      }

      if (now.difference(lastNotifTime).inMinutes < 1) return;

      final schedules = await _firestore.getFeedingSchedules();
      final activePakan = schedules.where((s) => s.isActive && s.feedType == 'pakan').toList();

      for (final s in activePakan) {
        final parts = s.time.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]) ?? 0;
        final int minute = int.tryParse(parts[1]) ?? 0;

        DateTime checkDate = DateTime(lastNotifTime.year, lastNotifTime.month, lastNotifTime.day);
        final endDate = DateTime(now.year, now.month, now.day);

        while (checkDate.isBefore(endDate) || checkDate.isAtSameMomentAs(endDate)) {
          final occurrence = DateTime(checkDate.year, checkDate.month, checkDate.day, hour, minute)
              .subtract(const Duration(minutes: 1));
          
          if (occurrence.isAfter(lastNotifTime) && occurrence.isBefore(now)) {
            final formattedTime = s.time;
            await _firestore.createNotification(
              title: 'Pemberian Pakan',
              body: 'Waktunya ayam makan! Jam: $formattedTime WIB',
              createdAt: occurrence,
            );
            debugPrint('[NotificationSync] Membuat log pakan terlewat untuk jam $formattedTime pada tanggal $occurrence');
          }
          checkDate = checkDate.add(const Duration(days: 1));
        }
      }
    } catch (e) {
      debugPrint('[NotificationSync] Gagal mencocokkan jadwal terlewat: $e');
    }
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


// lib/core/providers/schedule_provider.dart
//
// State management untuk Jadwal Pakan menggunakan Riverpod dan Cloud Firestore.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/feeding_schedule_model.dart';
import '../../data/services/firestore_service.dart';

// Provider global untuk instance FirestoreService (singleton).
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// State untuk daftar jadwal.
typedef ScheduleState = AsyncValue<List<FeedingScheduleModel>>;

// Provider yang mengelola daftar jadwal pakan.
final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, ScheduleState>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return ScheduleNotifier(service);
});

class ScheduleNotifier extends StateNotifier<ScheduleState> {
  final FirestoreService _firestore;
  StreamSubscription? _subscription;

  ScheduleNotifier(this._firestore) : super(const AsyncValue.loading()) {
    loadSchedules();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Memulai sinkronisasi data real-time dengan Cloud Firestore.
  Future<void> loadSchedules() async {
    _subscription?.cancel();
    _subscription = _firestore.watchFeedingSchedules().listen(
      (schedules) {
        state = AsyncValue.data(schedules);
      },
      onError: (err, stack) {
        state = AsyncValue.error(err, stack);
      },
    );
  }

  /// Membuat jadwal pakan baru.
  Future<void> createSchedule(FeedingScheduleModel newSchedule) async {
    await _firestore.createFeedingSchedule(newSchedule);
  }

  /// Memperbarui jadwal yang ada.
  Future<void> updateSchedule(FeedingScheduleModel updated) async {
    String firestoreId = updated.firestoreId;
    // Jika firestoreId kosong (karena dibuat baru di UI tanpa id Firestore),
    // lakukan pencarian berdasarkan hashcode/int id.
    if (firestoreId.isEmpty) {
      final list = state.valueOrNull ?? [];
      for (final s in list) {
        if (s.id == updated.id) {
          firestoreId = s.firestoreId;
          break;
        }
      }
    }
    if (firestoreId.isEmpty) {
      throw Exception('Jadwal tidak ditemukan untuk diperbarui.');
    }
    final withId = updated.copyWith(firestoreId: firestoreId);
    await _firestore.updateFeedingSchedule(withId);
  }

  /// Menghapus jadwal.
  Future<void> deleteSchedule(dynamic id) async {
    String? firestoreId;
    if (id is String) {
      firestoreId = id;
    } else if (id is int) {
      final list = state.valueOrNull ?? [];
      for (final s in list) {
        if (s.id == id) {
          firestoreId = s.firestoreId;
          break;
        }
      }
    }
    if (firestoreId != null) {
      await _firestore.deleteFeedingSchedule(firestoreId);
    }
  }

  /// Mengembalikan daftar jadwal pakan (feed_type == 'pakan') yang tersimpan.
  List<FeedingScheduleModel> get pakanSchedules {
    final all = state.valueOrNull ?? [];
    return all.where((s) => s.feedType == 'pakan').toList();
  }

  /// Mengembalikan jadwal berikutnya yang aktif berdasarkan waktu saat ini.
  FeedingScheduleModel? get nextSchedule {
    final all = state.valueOrNull ?? [];
    final active = all.where((s) => s.isActive).toList();
    if (active.isEmpty) return null;

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    FeedingScheduleModel? next;
    int minDiff = 1441;

    for (final s in active) {
      final parts = s.time.split(':');
      if (parts.length != 2) continue;
      final schedMinutes =
          int.tryParse(parts[0])! * 60 + int.tryParse(parts[1])!;

      var diff = schedMinutes - nowMinutes;
      if (diff < 0) diff += 1440;

      if (diff < minDiff) {
        minDiff = diff;
        next = s;
      }
    }

    return next;
  }
}


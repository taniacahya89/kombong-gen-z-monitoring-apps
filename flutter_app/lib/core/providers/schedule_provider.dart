// lib/core/providers/schedule_provider.dart
//
// State management untuk Jadwal Pakan menggunakan Riverpod.
//
// Provider yang disediakan:
//   - scheduleProvider: mengelola daftar jadwal pakan dari backend.
//     Mendukung operasi CRUD yang secara otomatis menyinkronkan state lokal
//     tanpa perlu fetch ulang dari server (optimistic update).
//
// Logika RBAC:
//   RBAC tidak diimplementasikan di provider ini; provider hanya meneruskan
//   permintaan ke ApiService. Jika user adalah guest, backend akan menolak
//   request mutasi dengan 403 Forbidden, dan error tersebut akan dilempar
//   kembali ke UI untuk ditampilkan sebagai pesan kesalahan.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/feeding_schedule_model.dart';
import '../../data/services/api_service.dart';
import 'auth_provider.dart';

// State untuk daftar jadwal.
typedef ScheduleState = AsyncValue<List<FeedingScheduleModel>>;

// Provider yang mengelola daftar jadwal pakan.
final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, ScheduleState>((ref) {
  final service = ref.watch(authServiceProvider);
  return ScheduleNotifier(service);
});

/// ScheduleNotifier mengelola daftar jadwal pakan.
/// Menyediakan operasi CRUD yang:
///   1. Memanggil endpoint API yang sesuai.
///   2. Memperbarui state lokal secara langsung (tanpa fetch ulang) untuk
///      menghindari loading state yang tidak perlu saat user melakukan mutasi.
class ScheduleNotifier extends StateNotifier<ScheduleState> {
  final ApiService _api;

  ScheduleNotifier(this._api) : super(const AsyncValue.loading()) {
    loadSchedules();
  }

  /// Mengambil daftar jadwal dari backend dan menyimpan ke state.
  Future<void> loadSchedules() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _api.getFeedingSchedules());
  }

  /// Membuat jadwal pakan baru dan menambahkannya ke daftar lokal.
  ///
  /// Guard lokal: menolak jadwal bertipe "minum" sebelum request dikirim ke API.
  /// Ini memberikan feedback instan ke user tanpa menunggu round-trip ke server.
  Future<void> createSchedule(FeedingScheduleModel newSchedule) async {
    if (newSchedule.feedType == 'minum') {
      throw Exception('Jadwal minum tidak dapat dibuat. Hanya jadwal pakan yang dapat dikelola.');
    }
    final created = await _api.createFeedingSchedule(newSchedule);

    // Tambahkan ke state lokal tanpa fetch ulang
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([...current, created]);
  }

  /// Memperbarui jadwal yang ada dan menyinkronkan state lokal.
  ///
  /// Guard lokal: menolak modifikasi pada jadwal bertipe "minum".
  Future<void> updateSchedule(FeedingScheduleModel updated) async {
    if (updated.feedType == 'minum') {
      throw Exception('Jadwal minum tidak dapat diubah. Hanya jadwal pakan yang dapat dikelola.');
    }
    final savedSchedule = await _api.updateFeedingSchedule(updated);

    // Ganti item dengan ID yang sama di state lokal
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((s) => s.id == savedSchedule.id ? savedSchedule : s).toList(),
    );
  }

  /// Menghapus jadwal dan menghapusnya dari state lokal.
  Future<void> deleteSchedule(int id) async {
    await _api.deleteFeedingSchedule(id);

    // Hapus item dari state lokal
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((s) => s.id != id).toList());
  }

  /// Mengembalikan jadwal yang dikelompokkan berdasarkan feed_type.
  /// Menghasilkan dua list: [pakanList, minumList].
  (List<FeedingScheduleModel>, List<FeedingScheduleModel>) get groupedSchedules {
    final all = state.valueOrNull ?? [];
    final pakanList = all.where((s) => s.feedType == 'pakan').toList();
    final minumList = all.where((s) => s.feedType == 'minum').toList();
    return (pakanList, minumList);
  }

  /// Mengembalikan jadwal berikutnya yang aktif berdasarkan waktu saat ini.
  FeedingScheduleModel? get nextSchedule {
    final all = state.valueOrNull ?? [];
    final active = all.where((s) => s.isActive).toList();
    if (active.isEmpty) return null;

    // Urutkan berdasarkan waktu dan cari yang paling dekat dengan sekarang
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    FeedingScheduleModel? next;
    int minDiff = 1441; // lebih dari 24 jam (sentinel value)

    for (final s in active) {
      final parts = s.time.split(':');
      if (parts.length != 2) continue;
      final schedMinutes =
          int.tryParse(parts[0])! * 60 + int.tryParse(parts[1])!;

      // Selisih dalam menit; jika jadwal sudah lewat hari ini, hitung untuk besok
      var diff = schedMinutes - nowMinutes;
      if (diff < 0) diff += 1440; // tambahkan 24 jam

      if (diff < minDiff) {
        minDiff = diff;
        next = s;
      }
    }

    return next;
  }
}

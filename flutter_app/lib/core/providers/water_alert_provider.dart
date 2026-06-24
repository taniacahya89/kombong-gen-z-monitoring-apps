// lib/core/providers/water_alert_provider.dart
//
// Provider khusus untuk mengelola logika peringatan status air minum
// pada halaman Jadwal.
//
// Desain:
//   WaterAlertNotifier adalah StateNotifier yang:
//     1. Mengamati data waterTankProvider (FutureProvider yang sudah ada).
//     2. Menentukan apakah kondisi tangki kritis berdasarkan AppConfig.waterCriticalThreshold.
//     3. Memicu LocalNotificationService.showWaterTankAlert() dengan throttle
//        berbasis timestamp — notifikasi hanya dikirim jika belum ada notifikasi
//        yang dikirim dalam AppConfig.notificationCooldown terakhir.
//
// Mengapa bukan langsung dari schedule_screen.dart?
//   Logika bisnis (kapan notifikasi dikirim, apa kondisi kritis) tidak boleh
//   hidup di layer UI. Menempatkannya di provider membuatnya testable, reusable,
//   dan konsisten dengan pola StateNotifier yang sudah ada di codebase ini.
//
// Cara konsumsi:
//   ref.watch(waterAlertProvider) di ScheduleScreen untuk mendapatkan
//   WaterAlertState dan merender WaterStatusCard yang sesuai.
//
//   ref.read(waterAlertProvider.notifier).checkAndAlert() dipanggil setiap
//   kali waterTankProvider menghasilkan data baru (via ref.listen di notifier).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/local_notification_service.dart';
import '../constants/app_constants.dart';
import 'dashboard_provider.dart';

// ---------------------------------------------------------------------------
// STATE
// ---------------------------------------------------------------------------

class WaterAlertState {
  /// True jika level tangki berada di bawah AppConfig.waterCriticalThreshold.
  final bool isCritical;

  /// Persentase level tangki (0.0 - 1.0). Null jika data belum tersedia.
  final double? levelPercentage;

  /// Ketinggian tangki saat ini dalam cm. Null jika data belum tersedia.
  final double? currentHeightCm;

  /// Kapasitas maksimal tangki dalam cm. Null jika data belum tersedia.
  final double? maxCapacityCm;

  /// True jika sedang dalam proses memuat data sensor.
  final bool isLoading;

  const WaterAlertState({
    this.isCritical = false,
    this.levelPercentage,
    this.currentHeightCm,
    this.maxCapacityCm,
    this.isLoading = true,
  });

  WaterAlertState copyWith({
    bool? isCritical,
    double? levelPercentage,
    double? currentHeightCm,
    double? maxCapacityCm,
    bool? isLoading,
  }) {
    return WaterAlertState(
      isCritical: isCritical ?? this.isCritical,
      levelPercentage: levelPercentage ?? this.levelPercentage,
      currentHeightCm: currentHeightCm ?? this.currentHeightCm,
      maxCapacityCm: maxCapacityCm ?? this.maxCapacityCm,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ---------------------------------------------------------------------------
// NOTIFIER
// ---------------------------------------------------------------------------

class WaterAlertNotifier extends StateNotifier<WaterAlertState> {
  final Ref _ref;

  /// Timestamp terakhir notifikasi dikirim. Null jika belum pernah dikirim.
  /// Digunakan untuk throttle: notifikasi baru hanya dikirim jika selisih
  /// waktu dari lastNotifiedAt melebihi AppConfig.notificationCooldown.
  DateTime? _lastNotifiedAt;

  WaterAlertNotifier(this._ref) : super(const WaterAlertState()) {
    // Mulai pantau perubahan waterTankProvider.
    // ref.listen dipanggil di dalam notifier menggunakan Ref (bukan WidgetRef),
    // yang merupakan pola resmi Riverpod untuk interaksi provider-ke-provider.
    _ref.listen<AsyncValue>(waterTankProvider, (_, next) {
      next.whenData((tank) => _evaluate(
            levelPercentage: tank.levelPercentage,
            currentHeightCm: tank.currentHeightCm,
            maxCapacityCm: tank.maxCapacityCm,
          ));

      if (next.isLoading) {
        state = state.copyWith(isLoading: true);
      }

      if (next.hasError) {
        state = state.copyWith(isLoading: false);
      }
    });

    // Baca state awal jika waterTankProvider sudah memiliki data.
    final initial = _ref.read(waterTankProvider);
    initial.whenData((tank) => _evaluate(
          levelPercentage: tank.levelPercentage,
          currentHeightCm: tank.currentHeightCm,
          maxCapacityCm: tank.maxCapacityCm,
        ));
  }

  /// Mengevaluasi kondisi tangki dan memperbarui state.
  /// Jika kritis dan cooldown sudah lewat, kirim notifikasi.
  void _evaluate({
    required double levelPercentage,
    required double currentHeightCm,
    required double maxCapacityCm,
  }) {
    final isCritical = levelPercentage < AppConfig.waterCriticalThreshold;

    state = WaterAlertState(
      isCritical: isCritical,
      levelPercentage: levelPercentage,
      currentHeightCm: currentHeightCm,
      maxCapacityCm: maxCapacityCm,
      isLoading: false,
    );

    if (isCritical) {
      _maybeFireNotification();
    }
  }

  /// Mengirim notifikasi hanya jika cooldown sudah lewat.
  ///
  /// Alur anti-spam:
  ///   - Jika _lastNotifiedAt null (belum pernah) -> kirim
  ///   - Jika sudah lewat AppConfig.notificationCooldown -> kirim
  ///   - Jika belum lewat cooldown -> skip, tidak lakukan apa-apa
  void _maybeFireNotification() {
    final now = DateTime.now();

    if (_lastNotifiedAt != null) {
      final elapsed = now.difference(_lastNotifiedAt!);
      if (elapsed < AppConfig.notificationCooldown) return;
    }

    _lastNotifiedAt = now;

    LocalNotificationService.instance.showWaterTankAlert(
      id: 1001,
      title: AppStrings.waterNotifTitle,
      body: AppStrings.waterNotifBody,
    );
  }
}

// ---------------------------------------------------------------------------
// PROVIDER
// ---------------------------------------------------------------------------

final waterAlertProvider =
    StateNotifierProvider<WaterAlertNotifier, WaterAlertState>((ref) {
  return WaterAlertNotifier(ref);
});

// lib/core/providers/power_provider.dart
//
// State management untuk data kelistrikan (daya, tegangan, arus).
//
// Provider yang disediakan:
//   - powerLatestProvider: data terkini dari endpoint /sensors/power.
//   - powerHistoryProvider: data historis untuk grafik dari /sensors/power/history.
//
// Kedua provider bersifat FutureProvider agar mudah dikonsumsi
// dengan pola AsyncValue.when() di UI tanpa perlu StateNotifier.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/solar_metrics_model.dart';

import 'auth_provider.dart';

// Provider data terkini kelistrikan.
final powerLatestProvider = FutureProvider<SolarMetricsModel>((ref) async {
  final service = ref.watch(authServiceProvider);
  return service.getSolarMetricsLatest();
});

// Provider riwayat data kelistrikan untuk grafik.
// Parameter hours dapat dikonfigurasi melalui ProviderFamily jika diperlukan.
final powerHistoryProvider =
    FutureProvider<List<SolarMetricsModel>>((ref) async {
  final service = ref.watch(authServiceProvider);
  return service.getPowerHistory(hours: 12);
});

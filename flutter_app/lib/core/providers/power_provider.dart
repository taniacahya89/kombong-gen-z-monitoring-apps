// lib/core/providers/power_provider.dart
//
// State management untuk data kelistrikan (daya, tegangan, arus) menggunakan MQTT.
// Menggantikan polling/listening Firebase Realtime Database sebelumnya.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/solar_metrics_model.dart';
import 'sensor_provider.dart';

// Provider data terkini kelistrikan (voltase, arus, daya).
final powerLatestProvider = Provider<AsyncValue<SolarMetricsModel>>((ref) {
  final sensorStateAsync = ref.watch(sensorStateProvider);
  return sensorStateAsync.map(
    data: (asyncData) {
      final state = asyncData.value;
      return AsyncValue.data(SolarMetricsModel(
        voltage: state.voltage,
        current: state.currentAmpere,
        power: state.power,
        recordedAt: state.lastUpdated,
      ));
    },
    error: (asyncError) => AsyncValue.error(asyncError.error, asyncError.stackTrace),
    loading: (_) {
      final repo = ref.read(sensorRepositoryProvider);
      if (repo.currentState.voltage > 0 || repo.currentState.currentMilliAmpere > 0) {
        return AsyncValue.data(SolarMetricsModel(
          voltage: repo.currentState.voltage,
          current: repo.currentState.currentAmpere,
          power: repo.currentState.power,
          recordedAt: repo.currentState.lastUpdated,
        ));
      }
      return const AsyncValue.loading();
    },
  );
});

// Provider riwayat data kelistrikan untuk grafik (buffer in-memory dari MQTT).
// Awalnya kosong ketika aplikasi baru berjalan dan belum ada data masuk.
final powerHistoryProvider = Provider<AsyncValue<List<SolarMetricsModel>>>((ref) {
  final historyAsync = ref.watch(sensorHistoryProvider);
  return historyAsync.map(
    data: (asyncData) {
      final list = asyncData.value;
      final mapped = list.map((state) => SolarMetricsModel(
        voltage: state.voltage,
        current: state.currentAmpere,
        power: state.power,
        recordedAt: state.lastUpdated,
      )).toList();
      return AsyncValue.data(mapped);
    },
    error: (asyncError) => AsyncValue.error(asyncError.error, asyncError.stackTrace),
    loading: (_) {
      final repo = ref.read(sensorRepositoryProvider);
      final mapped = repo.history.map((state) => SolarMetricsModel(
        voltage: state.voltage,
        current: state.currentAmpere,
        power: state.power,
        recordedAt: state.lastUpdated,
      )).toList();
      if (mapped.isNotEmpty) {
        return AsyncValue.data(mapped);
      }
      return const AsyncValue.loading();
    },
  );
});

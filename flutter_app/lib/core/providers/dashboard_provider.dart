// lib/core/providers/dashboard_provider.dart
//
// Provider khusus Dashboard yang mengelola data sensor realtime dari MQTT.
// Menggantikan polling/listening Firebase Realtime Database sebelumnya.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../../data/models/water_tank_model.dart';
import '../../data/models/solar_metrics_model.dart';
import '../../core/utils/app_utils.dart';
import 'sensor_provider.dart';

// ---------------------------------------------------------------------------
// WATER TANK PROVIDER
// Memetakan SensorState MQTT ke WaterTankModel
// ---------------------------------------------------------------------------
final waterTankProvider = Provider<AsyncValue<WaterTankModel>>((ref) {
  final sensorStateAsync = ref.watch(sensorStateProvider);
  return sensorStateAsync.map(
    data: (asyncData) {
      final state = asyncData.value;
      return AsyncValue.data(WaterTankModel(
        currentHeightCm: state.distance,
        maxCapacityCm: 55.0, // Kapasitas tangki air tetap sesuai baseline
        status: AppUtils.getWaterTankStatus(state.distance / 55.0),
      ));
    },
    error: (asyncError) => AsyncValue.error(asyncError.error, asyncError.stackTrace),
    loading: (_) {
      // Menggunakan state cache terakhir dari repo jika ada
      final repo = ref.read(sensorRepositoryProvider);
      if (repo.currentState.distance > 0) {
        return AsyncValue.data(WaterTankModel(
          currentHeightCm: repo.currentState.distance,
          maxCapacityCm: 55.0,
          status: AppUtils.getWaterTankStatus(repo.currentState.distance / 55.0),
        ));
      }
      return const AsyncValue.loading();
    },
  );
});

// ---------------------------------------------------------------------------
// SOLAR / POWER LATEST PROVIDER
// Memetakan SensorState MQTT ke SolarMetricsModel
// ---------------------------------------------------------------------------
final solarLatestDashboardProvider = Provider<AsyncValue<SolarMetricsModel>>((ref) {
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

// ---------------------------------------------------------------------------
// DEVICE STATUS PROVIDER
// Menampilkan status koneksi broker MQTT ("online" atau "server_mqtt_disconnected").
// ---------------------------------------------------------------------------
final deviceStatusProvider = Provider<AsyncValue<Map<String, dynamic>>>((ref) {
  final connectionStateAsync = ref.watch(mqttConnectionStateProvider);
  return connectionStateAsync.map(
    data: (asyncData) {
      final state = asyncData.value;
      if (state == MqttConnectionState.connected) {
        return const AsyncValue.data({
          'status': 'online',
          'message': 'Terhubung ke server MQTT.',
        });
      } else {
        return const AsyncValue.data({
          'status': 'server_mqtt_disconnected',
          'message': 'Koneksi dengan server MQTT terputus.',
        });
      }
    },
    error: (asyncError) => AsyncValue.error(asyncError.error, asyncError.stackTrace),
    loading: (_) {
      final service = ref.read(mqttServiceProvider);
      if (service.connectionState == MqttConnectionState.connected) {
        return const AsyncValue.data({
          'status': 'online',
          'message': 'Terhubung ke server MQTT.',
        });
      }
      return const AsyncValue.data({
        'status': 'server_mqtt_disconnected',
        'message': 'Menghubungkan ke server MQTT...',
      });
    },
  );
});

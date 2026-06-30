// lib/core/providers/sensor_provider.dart
//
// Riverpod providers untuk MqttService dan SensorRepository.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../../data/models/sensor_state.dart';
import '../../data/services/mqtt_service.dart';
import '../../data/services/firebase_database_service.dart';
import '../../data/repositories/sensor_repository.dart';
import 'schedule_provider.dart'; // Untuk mengakses firestoreServiceProvider

/// Provider untuk instance FirebaseDatabaseService.
final firebaseDatabaseServiceProvider = Provider<FirebaseDatabaseService>((ref) {
  return FirebaseDatabaseService();
});

/// Provider untuk instance MqttService (singleton).
/// connect() dipanggil di sini agar koneksi MQTT otomatis dimulai
/// begitu service pertama kali di-resolve — tidak bergantung pada
/// provider mana yang kebetulan di-watch lebih dulu oleh UI.
final mqttServiceProvider = Provider<MqttService>((ref) {
  final service = MqttService();
  service.connect();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider untuk instance SensorRepository.
final sensorRepositoryProvider = Provider<SensorRepository>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  final firebaseDatabaseService = ref.watch(firebaseDatabaseServiceProvider);
  final repo = SensorRepository(mqttService, firestoreService, firebaseDatabaseService);
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Provider untuk memantau status koneksi MQTT secara real-time.
///
/// Menggunakan [MqttService.connectionStateStreamWithCurrent] agar
/// subscriber langsung menerima state terakhir (replay-1) dan tidak
/// terjebak di AsyncLoading jika event `connected` sudah di-emit
/// sebelum StreamProvider sempat subscribe.
final mqttConnectionStateProvider = StreamProvider<MqttConnectionState>((ref) {
  final service = ref.watch(mqttServiceProvider);
  return service.connectionStateStreamWithCurrent;
});

/// Provider untuk memantau nilai sensor tergabung (SensorState) secara real-time.
final sensorStateProvider = StreamProvider<SensorState>((ref) {
  final repo = ref.watch(sensorRepositoryProvider);
  return repo.sensorStateStream;
});

/// Provider untuk memantau daftar riwayat sensor (List<SensorState>) secara real-time.
final sensorHistoryProvider = StreamProvider<List<SensorState>>((ref) {
  final repo = ref.watch(sensorRepositoryProvider);
  return repo.sensorHistoryStream;
});

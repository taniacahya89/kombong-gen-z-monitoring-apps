// lib/data/services/firebase_database_service.dart
//
// Service untuk data sensor real-time dari Firebase Realtime Database.
// Menggantikan polling REST API sebelumnya.
//
// Struktur Realtime Database:
//   /sensors/water_tank/  -> current_height_cm, max_capacity_cm, status, recorded_at
//   /sensors/power/       -> voltage, current, power, recorded_at

import 'package:firebase_database/firebase_database.dart';
import '../models/water_tank_model.dart';
import '../models/solar_metrics_model.dart';

class FirebaseDatabaseService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // ---------------------------------------------------------------------------
  // WATER TANK - Stream real-time
  // ---------------------------------------------------------------------------
  Stream<WaterTankModel?> watchWaterTank() {
    return _database.ref('sensors/water_tank').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      final map = Map<String, dynamic>.from(data as Map);
      return WaterTankModel.fromRealtimeDb(map);
    });
  }

  // Baca sekali (untuk provider FutureProvider)
  Future<WaterTankModel> getWaterTankLatest() async {
    final snapshot = await _database.ref('sensors/water_tank').get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Belum ada data tangki air dari perangkat IoT.');
    }
    final map = Map<String, dynamic>.from(snapshot.value as Map);
    return WaterTankModel.fromRealtimeDb(map);
  }

  // ---------------------------------------------------------------------------
  // POWER/SOLAR - Stream real-time
  // ---------------------------------------------------------------------------
  Stream<SolarMetricsModel?> watchPower() {
    return _database.ref('sensors/power').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      final map = Map<String, dynamic>.from(data as Map);
      return SolarMetricsModel.fromRealtimeDb(map);
    });
  }

  Future<SolarMetricsModel> getPowerLatest() async {
    final snapshot = await _database.ref('sensors/power').get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Belum ada data kelistrikan dari perangkat IoT.');
    }
    final map = Map<String, dynamic>.from(snapshot.value as Map);
    return SolarMetricsModel.fromRealtimeDb(map);
  }

  // ---------------------------------------------------------------------------
  // DEVICE STATUS - cek apakah perangkat masih aktif mengirim data
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getDeviceStatus() async {
    const offlineThresholdMs = 5 * 60 * 1000; // 5 menit dalam millisecond

    try {
      final waterSnap = await _database.ref('sensors/water_tank/recorded_at').get();
      final powerSnap = await _database.ref('sensors/power/recorded_at').get();

      if (!waterSnap.exists && !powerSnap.exists) {
        return {'status': 'no_data', 'message': 'Belum ada data sensor yang diterima.'};
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      int? lastTimestamp;

      if (waterSnap.exists && waterSnap.value != null) {
        lastTimestamp = waterSnap.value as int?;
      }
      if (powerSnap.exists && powerSnap.value != null) {
        final powerTs = powerSnap.value as int?;
        if (powerTs != null && (lastTimestamp == null || powerTs > lastTimestamp)) {
          lastTimestamp = powerTs;
        }
      }

      if (lastTimestamp == null) {
        return {'status': 'no_data', 'message': 'Belum ada data sensor.'};
      }

      final diffMs = now - lastTimestamp;
      final diffMinutes = diffMs ~/ 60000;

      if (diffMs > offlineThresholdMs) {
        return {
          'status': 'offline',
          'message': 'Perangkat tidak mengirimkan data selama lebih dari 5 menit.',
          'minutes_since_last_data': diffMinutes,
        };
      }

      return {
        'status': 'online',
        'message': 'Perangkat aktif dan mengirimkan data.',
        'minutes_since_last_data': diffMinutes,
      };
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal memeriksa status perangkat: $e'};
    }
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS TRIGGER - Stream real-time penambahan child baru
  // ---------------------------------------------------------------------------
  Stream<Map<String, dynamic>> watchNotificationsTrigger() {
    return _database.ref('notifications_trigger').onChildAdded.map((event) {
      final data = event.snapshot.value;
      if (data == null) return const {};
      return Map<String, dynamic>.from(data as Map);
    });
  }
}

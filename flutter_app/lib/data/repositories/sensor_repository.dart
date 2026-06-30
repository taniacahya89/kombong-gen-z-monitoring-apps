// lib/data/repositories/sensor_repository.dart
//
// Repository untuk mengolah data sensor mentah dari MqttService.
// Menggabungkan (merge) data parsial dari topik-topik terpisah ke dalam
// satu SensorState cache, serta melacak riwayat (history) data kelistrikan.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/sensor_state.dart';
import '../../data/services/mqtt_service.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/local_notification_service.dart';

class SensorRepository {
  final MqttService _mqttService;
  final FirestoreService _firestoreService;

  // Cache state saat ini (menggabungkan data parsial topik)
  SensorState _currentState = SensorState.initial();

  // Buffer riwayat in-memory untuk grafik Daya (awalnya kosong)
  final List<SensorState> _history = [];

  // StreamControllers untuk disebarkan ke Riverpod
  final _stateController = StreamController<SensorState>.broadcast();
  final _historyController = StreamController<List<SensorState>>.broadcast();

  // Subscription list agar mudah di-cancel jika dispose
  final List<StreamSubscription> _subscriptions = [];

  SensorRepository(this._mqttService, this._firestoreService) {
    _init();
  }

  void _init() {
    // 1. Dengarkan topik jarak (water tank)
    _subscriptions.add(
      _mqttService.distanceStream.listen((dist) {
        _currentState = _currentState.copyWith(
          distance: dist,
          lastUpdated: DateTime.now(),
        );
        _stateController.add(_currentState);
      }),
    );

    // 2. Dengarkan topik tegangan
    _subscriptions.add(
      _mqttService.voltageStream.listen((volt) {
        _currentState = _currentState.copyWith(
          voltage: volt,
          lastUpdated: DateTime.now(),
        );
        _stateController.add(_currentState);
        _addToHistory(_currentState);
      }),
    );

    // 3. Dengarkan topik arus (milliAmpere)
    _subscriptions.add(
      _mqttService.currentMilliAmpereStream.listen((currMA) {
        _currentState = _currentState.copyWith(
          currentMilliAmpere: currMA,
          lastUpdated: DateTime.now(),
        );
        _stateController.add(_currentState);
        _addToHistory(_currentState);
      }),
    );

    // 4. Dengarkan topik notifikasi pakan
    _subscriptions.add(
      _mqttService.feedNotificationStream.listen((msg) async {
        debugPrint('[SensorRepository] Diterima notifikasi pakan: $msg');

        // A. Log ke Firestore secara persisten (sesuai aturan arsitektur)
        try {
          await _firestoreService.createNotification(
            title: 'Pemberian Pakan',
            body: msg,
          );
        } catch (e) {
          debugPrint('[SensorRepository] Gagal menyimpan notifikasi ke Firestore: $e');
        }

        // B. Picu local push notification perangkat
        try {
          await LocalNotificationService.instance.showWaterTankAlert(
            id: 1002, // ID unik terpisah dari tangki air (1001)
            title: 'Pemberian Pakan',
            body: msg,
          );
        } catch (e) {
          debugPrint('[SensorRepository] Gagal memicu local push notification: $e');
        }
      }),
    );
  }

  /// Menambahkan telemetry baru ke buffer riwayat in-memory.
  void _addToHistory(SensorState state) {
    // Kita hanya mencatat ke riwayat jika data valid (bukan state inisial nol)
    if (state.voltage > 0 && state.currentMilliAmpere > 0) {
      _history.add(state);
      
      // Batasi buffer riwayat maksimal 8 data poin terakhir untuk grafik
      if (_history.length > 8) {
        _history.removeAt(0);
      }
      
      _historyController.add(List.from(_history));
    }
  }

  // Stream getter untuk Riverpod
  Stream<SensorState> get sensorStateStream => _stateController.stream;
  Stream<List<SensorState>> get sensorHistoryStream => _historyController.stream;

  // Getter nilai instan
  SensorState get currentState => _currentState;
  List<SensorState> get history => List.unmodifiable(_history);

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _stateController.close();
    _historyController.close();
  }
}

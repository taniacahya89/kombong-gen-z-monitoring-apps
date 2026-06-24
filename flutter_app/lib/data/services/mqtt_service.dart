// lib/data/services/mqtt_service.dart
//
// MQTT Service - Web-safe stub implementation.
//
// Catatan: mqtt_client menggunakan dart:io (TCP sockets) yang tidak tersedia
// di platform web. File ini menyediakan stub yang aman untuk web agar
// aplikasi bisa dikompilasi dan diuji di browser.
//
// Pada Fase 2 (Mobile/Desktop deployment), implementasi penuh akan diaktifkan
// menggunakan MqttServerClient dari package mqtt_client.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/water_tank_model.dart';
import '../models/solar_metrics_model.dart';
import '../models/feeding_schedule_model.dart';

// ---------------------------------------------------------------------------
// KONFIGURASI MQTT
// ---------------------------------------------------------------------------

class MqttConfig {
  static const String brokerHost = 'YOUR_MQTT_BROKER_HOST';
  static const int brokerPort = 1883;
  static const String clientId = 'kombong_genz_flutter_app';
  static const String username = '';
  static const String password = '';
}

// ---------------------------------------------------------------------------
// MQTT SERVICE CLASS
// Menggunakan StreamController broadcast untuk mendistribusikan data sensor.
// ---------------------------------------------------------------------------

class MqttService {
  final StreamController<WaterTankModel> _waterTankController =
      StreamController<WaterTankModel>.broadcast();

  final StreamController<SolarMetricsModel> _solarMetricsController =
      StreamController<SolarMetricsModel>.broadcast();

  Stream<WaterTankModel> get waterTankStream => _waterTankController.stream;
  Stream<SolarMetricsModel> get solarMetricsStream => _solarMetricsController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Timer? _simulationTimer;

  // ---------------------------------------------------------------------------
  // KONEKSI KE BROKER
  // Di web: hanya simulasi. Di mobile/desktop (Fase 2): koneksi MQTT nyata.
  // ---------------------------------------------------------------------------

  Future<void> connect() async {
    if (kIsWeb) {
      // Web tidak mendukung TCP MQTT. Jalankan simulasi saja.
      debugPrint('[MQTT] Platform web terdeteksi. Mode simulasi aktif.');
      _isConnected = false;
      return;
    }

    // TODO (Fase 2 - Mobile/Desktop):
    // Implementasi koneksi menggunakan MqttServerClient.
    //
    // import 'package:mqtt_client/mqtt_client.dart';
    // import 'package:mqtt_client/mqtt_server_client.dart';
    //
    // final client = MqttServerClient(MqttConfig.brokerHost, MqttConfig.clientId);
    // client.port = MqttConfig.brokerPort;
    // client.keepAlivePeriod = 60;
    // client.onConnected = _onConnected;
    // client.onDisconnected = _onDisconnected;
    //
    // final connMsg = MqttConnectMessage()
    //     .withClientIdentifier(MqttConfig.clientId)
    //     .startClean();
    // client.connectionMessage = connMsg;
    //
    // await client.connect(MqttConfig.username, MqttConfig.password);
    // _subscribeToTopics(client);

    debugPrint('[MQTT] Koneksi MQTT (stub Fase 1).');
  }

  // ---------------------------------------------------------------------------
  // PUBLISH KE TOPIK KONTROL
  // ---------------------------------------------------------------------------

  Future<void> publishFeedingSchedule(List<FeedingScheduleModel> schedules) async {
    final payload = json.encode({
      'feeding_schedules': schedules.map((s) => s.toJson()).toList(),
    });

    // TODO (Fase 2): Publish ke MQTT broker
    debugPrint('[MQTT] Publish jadwal pakan (stub): $payload');
  }

  // ---------------------------------------------------------------------------
  // SIMULASI DATA SENSOR
  // Fungsi ini adalah stub — tidak digunakan di production.
  // Data sensor diambil dari REST API backend, bukan MQTT langsung di Flutter.
  // ---------------------------------------------------------------------------

  void startSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_waterTankController.isClosed) {
        timer.cancel();
        return;
      }
      // Stub data — tidak memanggil factory yang tidak ada
      debugPrint('[MQTT] Simulasi (stub): gunakan REST API untuk data nyata.');
    });
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
  }

  // ---------------------------------------------------------------------------
  // CLEANUP
  // ---------------------------------------------------------------------------

  void dispose() {
    _simulationTimer?.cancel();
    _waterTankController.close();
    _solarMetricsController.close();
  }
}

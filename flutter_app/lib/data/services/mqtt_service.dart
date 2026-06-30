// lib/data/services/mqtt_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../../core/constants/app_constants.dart';

class MqttService {
  MqttServerClient? _client;

  final _connectionStateController = StreamController<MqttConnectionState>.broadcast();
  final _distanceController = StreamController<double>.broadcast();
  final _voltageController = StreamController<double>.broadcast();
  final _currentMilliAmpereController = StreamController<double>.broadcast();
  final _feedNotificationController = StreamController<String>.broadcast();

  /// Cache state koneksi terakhir agar subscriber baru langsung dapat nilai
  /// terkini (replay-1) — mengatasi race condition broadcast stream.
  MqttConnectionState _lastConnectionState = MqttConnectionState.disconnected;

  Stream<MqttConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<double> get distanceStream => _distanceController.stream;
  Stream<double> get voltageStream => _voltageController.stream;
  Stream<double> get currentMilliAmpereStream => _currentMilliAmpereController.stream;
  Stream<String> get feedNotificationStream => _feedNotificationController.stream;

  /// Stream yang langsung emit state terakhir ke subscriber baru,
  /// lalu forward semua event berikutnya dari broadcast stream.
  /// Digunakan oleh [mqttConnectionStateProvider] agar StreamProvider
  /// tidak terjebak di AsyncLoading.
  Stream<MqttConnectionState> get connectionStateStreamWithCurrent async* {
    yield _lastConnectionState;
    yield* _connectionStateController.stream;
  }

  MqttConnectionState get connectionState =>
      _client?.connectionStatus?.state ?? MqttConnectionState.disconnected;

  Future<void> connect() async {
    final clientId = '${MqttConfig.clientIdPrefix}${DateTime.now().millisecondsSinceEpoch}';

    debugPrint('[MQTT] Menghubungkan ke ${MqttConfig.broker}:${MqttConfig.port} '
        'dengan Client ID: $clientId');

    _client = MqttServerClient.withPort(
      MqttConfig.broker,
      clientId,
      MqttConfig.port,
    );

    // Plain MQTT — tanpa TLS
    _client!.secure = false;
    _client!.setProtocolV311();

    _client!.keepAlivePeriod = 20;
    _client!.autoReconnect = true;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onAutoReconnect = _onAutoReconnect;
    _client!.onAutoReconnected = _onAutoReconnected;
    _client!.pongCallback = _pongCallback;

    // Tanpa authenticateAs — broker publik EMQX tidak butuh kredensial
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();

    _client!.connectionMessage = connMessage;
    _emitConnectionState(MqttConnectionState.connecting);

    try {
      await _client!.connect();
    } catch (e) {
      debugPrint('[MQTT] Gagal terhubung: $e');
      _client!.disconnect();
      _emitConnectionState(MqttConnectionState.faulted);
      return;
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      debugPrint('[MQTT] Berhasil terhubung ke ${MqttConfig.broker}.');
      _emitConnectionState(MqttConnectionState.connected);
      _subscribeToTopics();
      _listenToUpdates();
    } else {
      debugPrint('[MQTT] Gagal terhubung. Status: ${_client!.connectionStatus!.state}');
      _client!.disconnect();
      _emitConnectionState(_client!.connectionStatus!.state);
    }
  }

  void _subscribeToTopics() {
    if (_client == null ||
        _client!.connectionStatus!.state != MqttConnectionState.connected) {
      return;
    }
    _client!.subscribe(MqttConfig.topicDistance, MqttQos.atMostOnce);
    _client!.subscribe(MqttConfig.topicVoltage, MqttQos.atMostOnce);
    _client!.subscribe(MqttConfig.topicCurrent, MqttQos.atMostOnce);
    _client!.subscribe(MqttConfig.topicFeedNotification, MqttQos.atLeastOnce);
  }

  void _listenToUpdates() {
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String topic = c[0].topic;
      final String payload =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      debugPrint('[MQTT] Diterima "$topic": $payload');
      _parseAndDispatch(topic, payload);
    });
  }

  void _parseAndDispatch(String topic, String payload) {
    try {
      if (topic == MqttConfig.topicDistance) {
        final val = double.tryParse(payload);
        if (val != null) _distanceController.add(val);
      } else if (topic == MqttConfig.topicVoltage) {
        final val = double.tryParse(payload);
        if (val != null) _voltageController.add(val);
      } else if (topic == MqttConfig.topicCurrent) {
        final val = double.tryParse(payload);
        if (val != null) _currentMilliAmpereController.add(val);
      } else if (topic == MqttConfig.topicFeedNotification) {
        _feedNotificationController.add(payload);
      }
    } catch (e) {
      debugPrint('[MQTT] Error parsing "$topic": $e');
    }
  }

  void disconnect() {
    _client?.disconnect();
  }

  void _onDisconnected() => _emitConnectionState(MqttConnectionState.disconnected);
  void _onConnected() => _emitConnectionState(MqttConnectionState.connected);
  void _onAutoReconnect() => _emitConnectionState(MqttConnectionState.connecting);
  void _onAutoReconnected() => _emitConnectionState(MqttConnectionState.connected);

  /// Helper: emit state ke broadcast stream DAN simpan ke cache.
  void _emitConnectionState(MqttConnectionState state) {
    _lastConnectionState = state;
    _connectionStateController.add(state);
  }
  void _pongCallback() => debugPrint('[MQTT] Pong diterima.');

  void dispose() {
    disconnect();
    _connectionStateController.close();
    _distanceController.close();
    _voltageController.close();
    _currentMilliAmpereController.close();
    _feedNotificationController.close();
  }
}
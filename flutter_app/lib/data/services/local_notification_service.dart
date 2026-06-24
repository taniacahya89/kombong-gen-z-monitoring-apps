// lib/data/services/local_notification_service.dart
//
// Service untuk mengirim local push notification ke perangkat.
//
// Implementasi:
//   - Menggunakan package flutter_local_notifications.
//   - Didesain sebagai singleton yang diinisialisasi sekali di main().
//   - Tidak bergantung pada Riverpod; bisa dipanggil dari provider maupun widget.
//
// Kanal Notifikasi Android:
//   ID: 'water_alert'  - Prioritas HIGH untuk peringatan tangki air.
//
// Anti-spam:
//   Service ini TIDAK mengelola anti-spam. Logika throttle dilakukan
//   oleh WaterAlertNotifier di schedule_provider.dart, yang memastikan
//   notifikasi hanya dikirim sekali per interval minimum 5 menit.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // INISIALISASI
  // Dipanggil satu kali di main() sebelum runApp().
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;

    // Konfigurasi platform Android:
    // @drawable/ic_launcher adalah ikon aplikasi default.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Konfigurasi platform iOS/macOS:
    // requestAlertPermission, requestBadgePermission, requestSoundPermission
    // akan ditampilkan ke pengguna pertama kali.
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
    debugPrint('[LocalNotification] Service diinisialisasi.');
  }

  // ---------------------------------------------------------------------------
  // KIRIM NOTIFIKASI PERINGATAN AIR
  // ---------------------------------------------------------------------------

  /// Mengirim notifikasi peringatan tangki air kosong.
  ///
  /// [id] harus unik per kategori notifikasi agar tidak saling menimpa
  /// secara tidak sengaja. Gunakan ID tetap (contoh: 1001) agar notifikasi
  /// yang sama dapat di-update (bukan duplikat).
  Future<void> showWaterTankAlert({
    int id = 1001,
    required String title,
    required String body,
  }) async {
    // Pada platform web, local notification tidak didukung.
    if (kIsWeb) {
      debugPrint('[LocalNotification] Platform web: notifikasi diabaikan.');
      return;
    }

    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'water_alert',           // channel ID
      'Peringatan Air Minum',  // channel name
      channelDescription: 'Notifikasi saat tangki air minum kandang kosong atau kritis.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(id, title, body, details);
    debugPrint('[LocalNotification] Notifikasi dikirim: $title');
  }
}

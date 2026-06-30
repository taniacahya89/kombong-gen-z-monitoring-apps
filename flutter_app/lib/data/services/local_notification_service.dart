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
//   ID: 'feeding_schedule' - Prioritas HIGH untuk alarm pakan.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/feeding_schedule_model.dart';

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

    // Inisialisasi timezone
    try {
      tz.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('[LocalNotification] Timezone diatur ke: $timeZoneName');
    } catch (e) {
      debugPrint('[LocalNotification] Gagal mengatur timezone: $e. Fallback ke UTC.');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // Konfigurasi platform Android:
    // @drawable/ic_launcher adalah ikon aplikasi default.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Konfigurasi platform iOS/macOS:
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
  Future<void> showWaterTankAlert({
    int id = 1001,
    required String title,
    required String body,
  }) async {
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

  // ---------------------------------------------------------------------------
  // JADWALKAN ALARM PAKAN
  // ---------------------------------------------------------------------------

  /// Menjadwalkan notifikasi harian berulang untuk jadwal pakan.
  Future<void> scheduleFeedingNotification(FeedingScheduleModel schedule) async {
    if (kIsWeb) return;
    if (!_initialized) await initialize();

    final parts = schedule.time.split(':');
    if (parts.length != 2) return;
    final int hour = int.tryParse(parts[0]) ?? 0;
    final int minute = int.tryParse(parts[1]) ?? 0;

    // Tentukan waktu scheduledDate pada hari ini
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Kurangi 1 menit agar notifikasi muncul 1 menit sebelum jam yang ditentukan
    scheduledDate = scheduledDate.subtract(const Duration(minutes: 1));

    // Jika waktu terjadwal sudah lewat hari ini, jadwalkan untuk besok
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'feeding_schedule', // channel ID
      'Jadwal Pakan',      // channel name
      channelDescription: 'Notifikasi pengingat pemberian pakan ayam.',
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

    // Gunakan hashcode firestoreId sebagai ID notifikasi unik (integer)
    final int notifId = schedule.firestoreId.hashCode;

    await _plugin.zonedSchedule(
      notifId,
      'Jadwal Pakan: ${schedule.label}',
      'Waktunya ayam makan! Jam: ${schedule.time} WIB',
      scheduledDate,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint('[LocalNotification] Jadwal pakan "${schedule.label}" disetel di jam ${schedule.time} (ID: $notifId)');
  }

  /// Membatalkan/menghapus jadwal notifikasi tertentu.
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    if (!_initialized) await initialize();
    await _plugin.cancel(id);
    debugPrint('[LocalNotification] Notifikasi ID $id dibatalkan.');
  }
}

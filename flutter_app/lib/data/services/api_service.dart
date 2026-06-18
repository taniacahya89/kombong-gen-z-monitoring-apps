// lib/data/services/api_service.dart
//
// Service layer untuk komunikasi REST API dengan backend Go Fiber.
// Implementasi Penuh - Fase 2 (diperbarui).
//
// Fitur utama:
//   - Dio interceptor request: menyisipkan JWT token dari flutter_secure_storage
//     secara otomatis ke setiap request yang memerlukan autentikasi.
//   - Interceptor error 401: menghapus token lokal dan mengarahkan pengguna
//     ke halaman Login secara otomatis via GoRouter (navigatorKey global).
//     Pengguna melihat pesan "Sesi Anda telah berakhir" bukan error teknis.
//   - Semua method berkomunikasi langsung ke PostgreSQL via backend Go.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../models/user_model.dart';
import '../models/water_tank_model.dart';
import '../models/solar_metrics_model.dart';
import '../models/feeding_schedule_model.dart';
import '../models/notification_model.dart';

// Kunci penyimpanan token di secure storage
const _keyAuthToken = 'auth_token';

// ---------------------------------------------------------------------------
// NAVIGATOR KEY GLOBAL
//
// Digunakan oleh Dio interceptor untuk menavigasi ke halaman Login
// saat menerima 401 Unauthorized, tanpa perlu BuildContext.
//
// Cara penggunaan di main.dart:
//   MaterialApp.router(
//     routerConfig: AppRoutes.router,
//   )
//
// GoRouter sudah menyediakan navigasi global melalui routerKey / routerDelegate.
// ApiService mengakses GoRouter langsung via AppRoutes.router.
// ---------------------------------------------------------------------------

class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  ApiService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Interceptor request: menyisipkan JWT token ke header Authorization
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: _keyAuthToken);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Jika server mengembalikan 401 (token kadaluarsa atau tidak valid):
          //  1. Hapus token lokal dari secure storage.
          //  2. Arahkan pengguna ke halaman Login secara otomatis.
          //  3. Tampilkan pesan "Sesi Anda telah berakhir" yang ramah pengguna.
          //
          // Ini memastikan skenario: user sedang menekan tombol Simpan Jadwal
          // tepat saat token expired - aplikasi tidak freeze atau crash; pengguna
          // langsung diarahkan ke Login dengan penjelasan yang jelas.
          if (error.response?.statusCode == 401) {
            await _secureStorage.delete(key: _keyAuthToken);

            // Navigasi ke Login menggunakan GoRouter global.
            // Delay singkat agar Dio menyelesaikan error handling terlebih dahulu.
            Future.delayed(Duration.zero, () {
              final context = AppRoutes.router.routerDelegate.navigatorKey.currentContext;
              if (context != null && context.mounted) {
                // Tampilkan notifikasi sebelum redirect
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Sesi Anda telah berakhir. Silakan login kembali.',
                      style: TextStyle(fontFamily: 'Outfit'),
                    ),
                    backgroundColor: Color(0xFFEF5350),
                    duration: Duration(seconds: 3),
                  ),
                );
                // Redirect ke Login dan hapus seluruh stack navigasi
                context.goNamed(AppRouteNames.login);
              }
            });
          }
          handler.next(error);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STORAGE HELPERS
  // ---------------------------------------------------------------------------

  /// Menyimpan JWT token ke secure storage setelah login/register berhasil.
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _keyAuthToken, value: token);
  }

  /// Menghapus JWT token dari secure storage (digunakan saat logout).
  Future<void> clearToken() async {
    await _secureStorage.delete(key: _keyAuthToken);
  }

  /// Membaca token yang tersimpan.
  Future<String?> getToken() async {
    return _secureStorage.read(key: _keyAuthToken);
  }

  /// Mengembalikan true jika token tersimpan ada (user sudah login).
  Future<bool> hasToken() async {
    final token = await _secureStorage.read(key: _keyAuthToken);
    return token != null && token.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // AUTENTIKASI
  // ---------------------------------------------------------------------------

  /// Login pengguna dengan email dan password.
  /// Menyimpan token ke secure storage secara otomatis jika berhasil.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.login,
      data: {
        'user': {'email': email, 'password': password},
      },
    );
    final user = UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
    if (user.token != null) {
      await saveToken(user.token!);
    }
    return user;
  }

  /// Registrasi pengguna baru.
  /// Menyimpan token ke secure storage secara otomatis jika berhasil.
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.register,
      data: {'name': name, 'email': email, 'password': password},
    );
    final user = UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
    if (user.token != null) {
      await saveToken(user.token!);
    }
    return user;
  }

  /// Logout: menghapus token lokal dan memanggil endpoint logout backend.
  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } catch (_) {
      // Abaikan error jaringan saat logout; hapus token lokal tetap dilakukan.
    } finally {
      await clearToken();
    }
  }

  /// Mengambil data profil user yang sedang login dari backend.
  Future<UserModel> getMe() async {
    final response = await _dio.get(ApiEndpoints.me);
    return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Mengubah kata sandi pengguna yang sedang login.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _dio.put(
      ApiEndpoints.changePassword,
      data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DATA SENSOR
  // ---------------------------------------------------------------------------

  /// Mengambil data terkini tangki air dari database.
  Future<WaterTankModel> getWaterTankLatest() async {
    final response = await _dio.get(ApiEndpoints.waterTankLatest);
    return WaterTankModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Mengambil data terkini kelistrikan dari database.
  Future<SolarMetricsModel> getSolarMetricsLatest() async {
    final response = await _dio.get(ApiEndpoints.powerLatest);
    return SolarMetricsModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Mengambil riwayat data kelistrikan untuk grafik historis.
  /// Parameter [hours] menentukan rentang waktu (default 12 jam).
  Future<List<SolarMetricsModel>> getPowerHistory({int hours = 12}) async {
    final response = await _dio.get(
      ApiEndpoints.powerHistory,
      queryParameters: {'hours': hours, 'limit': 100},
    );
    final history = response.data['data']['history'] as List;
    return history
        .map((e) => SolarMetricsModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // JADWAL PAKAN
  // ---------------------------------------------------------------------------

  /// Mengambil daftar semua jadwal pakan dari database.
  Future<List<FeedingScheduleModel>> getFeedingSchedules() async {
    final response = await _dio.get(ApiEndpoints.feedingSchedules);
    final list = response.data['data']['feeding_schedules'] as List;
    return list
        .map((e) => FeedingScheduleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Membuat jadwal pakan baru (hanya untuk role warga).
  Future<FeedingScheduleModel> createFeedingSchedule(
    FeedingScheduleModel schedule,
  ) async {
    final response = await _dio.post(
      ApiEndpoints.feedingSchedules,
      data: schedule.toCreatePayload(),
    );
    return FeedingScheduleModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Memperbarui jadwal pakan yang sudah ada (hanya untuk role warga).
  Future<FeedingScheduleModel> updateFeedingSchedule(
    FeedingScheduleModel schedule,
  ) async {
    final response = await _dio.put(
      '${ApiEndpoints.feedingSchedules}/${schedule.id}',
      data: schedule.toUpdatePayload(),
    );
    return FeedingScheduleModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Menghapus jadwal pakan berdasarkan ID (hanya untuk role warga).
  Future<void> deleteFeedingSchedule(int id) async {
    await _dio.delete('${ApiEndpoints.feedingSchedules}/$id');
  }

  // ---------------------------------------------------------------------------
  // NOTIFIKASI
  // ---------------------------------------------------------------------------

  /// Mengambil daftar riwayat notifikasi sistem.
  Future<Map<String, dynamic>> getNotifications({int limit = 50}) async {
    final response = await _dio.get(
      ApiEndpoints.notifications,
      queryParameters: {'limit': limit},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final list = data['notifications'] as List;
    return {
      'notifications': list
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      'unread_count': data['unread_count'] as int? ?? 0,
    };
  }

  /// Menandai satu notifikasi sebagai sudah dibaca.
  Future<void> markNotificationRead(int id) async {
    await _dio.put('${ApiEndpoints.notifications}/$id/read');
  }

  /// Menandai semua notifikasi sebagai sudah dibaca.
  Future<void> markAllNotificationsRead() async {
    await _dio.put(ApiEndpoints.notificationsReadAll);
  }

  /// Mengambil status online/offline perangkat IoT.
  Future<Map<String, dynamic>> getDeviceStatus() async {
    final response = await _dio.get(ApiEndpoints.deviceStatus);
    return response.data['data'] as Map<String, dynamic>;
  }
}

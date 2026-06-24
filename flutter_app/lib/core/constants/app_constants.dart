// lib/core/constants/app_constants.dart
//
// Pusat definisi semua konstanta aplikasi.
// Mencakup: warna, string, ukuran, topik MQTT, dan endpoint API.
// Dianalisis dari desain UI: background hijau muda, primary hijau tua, kartu putih.

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// WARNA APLIKASI
// Diekstrak dari gambar desain:
//   - Background utama: hijau muda pastel (#E8F5E2)
//   - Primary (tombol, aksen): hijau tua (#2D7A27)
//   - Kartu: putih murni
//   - Teks primer: hampir hitam (#1A1A1A)
//   - Teks sekunder: abu (#757575)
// ---------------------------------------------------------------------------

class AppColors {
  AppColors._();

  // Warna Latar Belakang
  static const Color background = Color(0xFFE8F5E2);
  static const Color backgroundLight = Color(0xFFF0FAF0);
  static const Color surface = Color(0xFFFFFFFF);

  // Warna Primer (Hijau Utama)
  static const Color primary = Color(0xFF2D7A27);
  static const Color primaryDark = Color(0xFF1E5A1A);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color primaryContainer = Color(0xFFD4EDDA);

  // Warna Sekunder / Aksen
  static const Color accent = Color(0xFF43A047);
  static const Color accentOrange = Color(0xFFFF6B35);

  // Warna Teks
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textAccentGreen = Color(0xFF2D7A27);
  static const Color textAccentRed = Color(0xFFE53935);

  // Warna Form / Input Field
  static const Color inputFill = Color(0xFFF2F2F2);
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color inputFocusBorder = Color(0xFF2D7A27);

  // Warna Status Tangki Air (Gradient dari bawah ke atas)
  static const Color tankLevelRed = Color(0xFFE53935);
  static const Color tankLevelOrange = Color(0xFFFF7043);
  static const Color tankLevelYellow = Color(0xFFFDD835);
  static const Color tankLevelYellowGreen = Color(0xFF9CCC65);
  static const Color tankLevelGreen = Color(0xFF43A047);

  // Warna Chart Sparkline
  static const Color chartGreen = Color(0xFF4CAF50);
  static const Color chartRed = Color(0xFFE53935);
  static const Color chartYellow = Color(0xFFFDD835);

  // Warna Bottom Navigation Bar
  static const Color navBarBackground = Color(0xFF2D7A27);
  static const Color navBarActive = Color(0xFFFFFFFF);
  static const Color navBarInactive = Color(0xFFADD1A8);

  // Warna Bayangan Kartu
  static const Color shadow = Color(0x14000000);
  static const Color shadowMedium = Color(0x1F000000);

  // Warna Divider
  static const Color divider = Color(0xFFEEEEEE);

  // Splash Screen Background (fallback jika gambar tidak tersedia)
  static const Color splashBackground = Color(0xFFF5E6C8);
  static const Color splashTitle = Color(0xFF5D4037);
  static const Color splashButton = Color(0xFF5D4037);
}

// ---------------------------------------------------------------------------
// STRING APLIKASI
// ---------------------------------------------------------------------------

class AppStrings {
  AppStrings._();

  // Nama Aplikasi
  static const String appName = 'Kombong GenZ';
  static const String appTagline = 'Smart Monitoring for Smart Farming';

  // Splash Screen
  static const String splashButtonLabel = 'Mulai';

  // Login Screen
  static const String loginTitle = 'Selamat Datang';
  static const String loginSubtitle = 'Masuk ke akun Anda untuk melanjutkan';
  static const String loginEmailLabel = 'Email';
  static const String loginEmailHint = 'nama@gmail.com';
  static const String loginPasswordLabel = 'Password';
  static const String loginPasswordHint = '••••••••••';
  static const String loginForgotPassword = 'Lupa password?';
  static const String loginButton = 'Masuk';
  static const String loginNoAccount = 'Belum punya akun?';
  static const String loginRegisterLink = 'Daftar';

  // Sign Up Screen
  static const String signupTitle = 'Buat Akun Baru';
  static const String signupSubtitle = 'Daftarkan akun untuk memulai';
  static const String signupNameLabel = 'Nama Lengkap';
  static const String signupNameHint = 'Nama Kamu';
  static const String signupEmailLabel = 'Email';
  static const String signupEmailHint = 'nama@gmail.com';
  static const String signupPasswordLabel = 'Password';
  static const String signupPasswordHint = 'Minimal 8 karakter';
  static const String signupButton = 'Daftar';
  static const String signupHasAccount = 'Sudah punya akun?';
  static const String signupLoginLink = 'Masuk';

  // Dashboard Screen
  static const String dashboardGreeting = 'Selamat Datang,';
  static const String dashboardUserHighlight = 'User';
  static const String dashboardFarmName = 'Kombong Gen Z';

  // Kartu Water Tank
  static const String waterTankTitle = 'Water Tank';
  static const String waterTankCapacityLabel = 'of 55 cm capacity';
  static const String waterTankStatusSafe = 'Kapasitas Air Tercukupi';
  static const String waterTankStatusWarning = 'Kapasitas Air Menengah';
  static const String waterTankStatusLow = 'Kapasitas Air Rendah';

  // Kartu Next Schedule
  static const String nextScheduleTitle = 'NEXT SCHEDULE';
  static const String scheduleChickenFeed = 'PAKAN AYAM';
  static const String scheduleChickenDrink = 'MINUM AYAM';

  // Kartu Live Energy
  static const String liveEnergyTitle = 'LIVE ENERGY';
  static const String energyCurrent = 'CURRENT';
  static const String energyVoltage = 'VOLTAGE';
  static const String energyPower = 'POWER';
  static const String energyUnitAmpere = 'A';
  static const String energyUnitVolt = 'V';
  static const String energyUnitWatt = 'W';

  // Bottom Navigation
  static const String navDashboard = 'Dashboard';
  static const String navSchedule = 'Jadwal Pakan';
  static const String navPower = 'Daya';
  static const String navProfile = 'Profil';

  // Halaman Jadwal Pakan
  static const String schedulePageTitle = 'Jadwal Makan';
  static const String schedulePageSubtitle = 'Atur waktu makan dan minum ayam.';
  static const String scheduleNextLabel = 'Jadwal berikutnya';
  static const String scheduleSectionPakan = 'Pakan Ayam';
  static const String scheduleSectionMinum = 'Minum Ayam';
  static const String scheduleAddButton = 'Tambah Jadwal';
  static const String scheduleGuestWarning = 'Anda login sebagai tamu. Hanya warga yang dapat mengelola jadwal.';

  // Halaman Info Pakan Ayam (Panduan Nutrisi)
  static const String feedNutritionBannerLabel = 'Lihat Panduan Nutrisi';
  static const String feedNutritionBannerSub = 'Komposisi & porsi pakan per kelompok umur';
  static const String feedNutritionPageTitle = 'Info Pakan Ayam';
  static const String feedNutritionPageSubtitle = 'Panduan nutrisi & komposisi pakan harian';
  static const String feedNutritionTabMorning = 'Jadwal Pagi';
  static const String feedNutritionTabAfternoon = 'Jadwal Sore';
  static const String feedNutritionPorsiLabel = 'Porsi';
  static const String feedNutritionKomposisiLabel = 'Komposisi';
  static const String feedNutritionKeteranganLabel = 'Keterangan';

  // Halaman Daya
  static const String powerPageTitle = 'Tegangan dan Arus';
  static const String powerPageSubtitle = 'Monitoring daya listrik kandang.';
  static const String powerGenerating = 'GENERATING POWER';
  static const String powerCurrent = 'CURRENT';
  static const String powerVoltage = 'VOLTAGE';

  // Water Status Card (pada halaman Jadwal)
  static const String waterStatusTitle = 'Status Air Minum';
  static const String waterStatusSafe = 'Air Minum Tersedia';
  static const String waterStatusCritical = 'Tangki Air Kritis';
  static const String waterStatusSubSafe = 'Tersedia otomatis. Tangki dalam kondisi aman.';
  static const String waterStatusSubCritical = 'Segera isi tangki! Kapasitas air di bawah batas aman.';
  static const String waterNotifTitle = 'Air Minum Kandang Habis';
  static const String waterNotifBody = 'Air Minum Kandang Habis, Segera Isi Tangki';

  // Halaman Profil
  static const String profilePageTitle = 'Profil';
  static const String profileSubtitle = 'Informasi akun Anda.';
  static const String profileEmailLabel = 'EMAIL';
  static const String profileSecurityLabel = 'Keamanan Akun';
  static const String profileLogoutButton = 'LOGOUT';
  static const String profileRoleGuest = 'Tamu (Guest)';
  static const String profileRoleWarga = 'Warga';

  // Halaman Notifikasi
  static const String notifPageTitle = 'Notifikasi';
  static const String notifPageSubtitle = 'Riwayat peringatan sistem.';
  static const String notifMarkAllRead = 'Tandai Semua Dibaca';
  static const String notifEmpty = 'Belum ada notifikasi';

  // Ubah Password
  static const String changePasswordTitle = 'Ubah Kata Sandi';
  static const String changePasswordOld = 'Password Lama';
  static const String changePasswordNew = 'Password Baru';
  static const String changePasswordConfirm = 'Konfirmasi Password Baru';
  static const String changePasswordButton = 'Simpan Password Baru';

  // Pesan Error / Validasi
  static const String errorPasswordMismatch = 'Konfirmasi password tidak cocok';
  static const String comingSoon = 'Halaman ini akan segera tersedia';

  // Pesan Error / Validasi
  static const String errorEmailEmpty = 'Email tidak boleh kosong';
  static const String errorEmailInvalid = 'Format email tidak valid';
  static const String errorPasswordEmpty = 'Password tidak boleh kosong';
  static const String errorPasswordShort = 'Password minimal 8 karakter';
  static const String errorNameEmpty = 'Nama tidak boleh kosong';
}

// ---------------------------------------------------------------------------
// TOPIK MQTT
// ---------------------------------------------------------------------------

class MqttTopics {
  MqttTopics._();

  // Subscribe: Data dari perangkat IoT ke aplikasi
  static const String waterTankSensor = 'iot/pengabdian/sensor/tangki';
  static const String solarSensor = 'iot/pengabdian/sensor/listrik';

  // Publish: Kontrol dari aplikasi ke perangkat IoT
  static const String feedingControl = 'iot/pengabdian/kontrol/pakan';
}

// ---------------------------------------------------------------------------
// ENDPOINT API (Backend Go Fiber)
// Akan diaktifkan pada Fase 2 saat backend siap.
// ---------------------------------------------------------------------------

class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = 'http://localhost:3000/api/v1';
  // Catatan: localhost digunakan untuk web (Chrome) dan Windows desktop.
  // Ganti ke 10.0.2.2 untuk emulator Android, atau IP lokal (192.168.x.x)
  // untuk perangkat fisik Android/iOS.

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String changePassword = '/auth/change-password';

  // Sensor Data
  static const String waterTankLatest = '/sensors/water-tank';
  static const String waterTankHistory = '/sensors/water-tank/history';
  static const String powerLatest = '/sensors/power';
  static const String powerHistory = '/sensors/power/history';
  static const String deviceStatus = '/sensors/status';

  // Jadwal Pakan
  static const String feedingSchedules = '/feeding/schedules';

  // Notifikasi
  static const String notifications = '/notifications';
  static const String notificationsReadAll = '/notifications/read-all';
}

// ---------------------------------------------------------------------------
// UKURAN & SPASI (SPACING SYSTEM)
// ---------------------------------------------------------------------------

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Padding konten halaman
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(20.0);
}

// ---------------------------------------------------------------------------
// BORDER RADIUS
// ---------------------------------------------------------------------------

class AppRadius {
  AppRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 28.0;
  static const double full = 100.0;
}

// ---------------------------------------------------------------------------
// ASET PATH
// ---------------------------------------------------------------------------

class AppAssets {
  AppAssets._();

  // Gambar
  // CATATAN: splash_bg.png wajib ditempatkan di assets/images/ sebelum build.
  static const String splashBackground = 'assets/images/splash_bg.png';
  static const String avatarDefault = 'assets/images/avatar_default.png';

  // Font: Poppins via google_fonts package (tidak perlu file TTF lokal)
  // Nilai ini masih digunakan sebagai fallback di beberapa widget.
  static const String fontFamily = 'Poppins';
}

// ---------------------------------------------------------------------------
// DURASI ANIMASI
// ---------------------------------------------------------------------------

class AppDuration {
  AppDuration._();

  static const Duration splashTimer = Duration(seconds: 3);
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration long = Duration(milliseconds: 500);
}

// ---------------------------------------------------------------------------
// KONFIGURASI BISNIS
// ---------------------------------------------------------------------------

class AppConfig {
  AppConfig._();

  /// Batas level tangki air (0.0 - 1.0) yang dianggap kritis.
  /// Level di bawah nilai ini akan memicu peringatan dan notifikasi.
  /// 0.3 = 30% dari kapasitas penuh (sejajar dengan kategori "Rendah"
  /// yang ditetapkan oleh AppUtils.getWaterTankStatus).
  static const double waterCriticalThreshold = 0.3;

  /// Interval minimum antar dua local push notification untuk kategori
  /// yang sama. Mencegah spam jika sensor terus melaporkan level kritis.
  /// Nilai 5 menit dipilih agar pengguna tidak terganggu tetapi tetap
  /// mendapat pengingat jika aplikasi dibiarkan terbuka lama.
  static const Duration notificationCooldown = Duration(minutes: 5);
}


// lib/core/providers/dashboard_provider.dart
//
// Provider khusus Dashboard yang mengelola polling data real-time.
//
// Arsitektur untuk rebuild selektif:
//
//   dashboard_provider.dart memisahkan state menjadi tiga provider independen:
//
//   1. waterTankProvider  - hanya widget kartu tangki air yang memanggil ini
//   2. solarLatestProvider - hanya widget kartu energi yang memanggil ini
//   3. deviceStatusProvider - hanya widget banner offline yang memanggil ini
//
//   Setiap provider adalah FutureProvider terpisah. Saat polling memperbarui
//   satu provider (misal solar), hanya widget yang watch(solarLatestProvider)
//   yang di-rebuild. Widget lain seperti kartu tangki air tidak tersentuh.
//
// Polling real-time:
//   Dilakukan via Timer.periodic di DashboardScreen dengan interval 30 detik.
//   Timer memanggil ref.invalidate(providerX) yang memicu FutureProvider
//   untuk fetch ulang data dari API - tanpa setState() atau full page rebuild.
//
// Status perangkat:
//   deviceStatusProvider memanggil endpoint /sensors/status setiap polling.
//   Jika status "offline", DashboardScreen menampilkan banner peringatan.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/water_tank_model.dart';
import '../../data/models/solar_metrics_model.dart';
import '../../data/services/api_service.dart';
import 'auth_provider.dart';

// ---------------------------------------------------------------------------
// WATER TANK PROVIDER
// Hanya widget WaterTankCard yang watch provider ini.
// ---------------------------------------------------------------------------
final waterTankProvider = FutureProvider<WaterTankModel>((ref) async {
  final service = ref.watch(authServiceProvider);
  return service.getWaterTankLatest();
});

// ---------------------------------------------------------------------------
// SOLAR / POWER LATEST PROVIDER
// Hanya widget EnergyCard yang watch provider ini.
// ---------------------------------------------------------------------------
final solarLatestDashboardProvider = FutureProvider<SolarMetricsModel>((ref) async {
  final service = ref.watch(authServiceProvider);
  return service.getSolarMetricsLatest();
});

// ---------------------------------------------------------------------------
// DEVICE STATUS PROVIDER
// Mengembalikan string status: "online", "offline", "no_data", atau
// "server_mqtt_disconnected". Hanya banner peringatan yang watch ini.
// ---------------------------------------------------------------------------
final deviceStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(authServiceProvider);
  return service.getDeviceStatus();
});

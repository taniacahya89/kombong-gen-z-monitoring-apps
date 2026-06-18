// lib/main.dart
//
// Titik masuk utama aplikasi Flutter - Kombong GenZ
// IoT Monitoring System untuk Pengabdian Masyarakat
//
// Menginisialisasi:
//   - ProviderScope (flutter_riverpod) untuk state management
//   - GoRouter untuk navigasi
//   - AppTheme untuk tema Material Design 3
//   - System UI overlay (status bar transparan)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kunci orientasi layar ke portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Konfigurasi tampilan status bar sistem
  // Ikon gelap agar terlihat di atas background hijau muda
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.navBarBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    // ProviderScope diperlukan oleh flutter_riverpod untuk injeksi state
    const ProviderScope(
      child: KombongGenZApp(),
    ),
  );
}

class KombongGenZApp extends StatelessWidget {
  const KombongGenZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRoutes.router,
    );
  }
}

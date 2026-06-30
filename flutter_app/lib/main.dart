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
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'data/services/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Firebase Core dengan try-catch untuk debugging
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[Firebase] Inisialisasi berhasil.');
    } else {
      debugPrint('[Firebase] Sudah terinisialisasi.');
    }
  } catch (e, stack) {
    debugPrint('[Firebase] Error saat inisialisasi: $e');
    debugPrint('[Firebase] StackTrace: $stack');
  }

  // setPreferredOrientations hanya relevan di mobile — tidak perlu di web/desktop
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Inisialisasi local push notification service.
  // Dilewati di platform web karena flutter_local_notifications tidak mendukung web.
  await LocalNotificationService.instance.initialize();

  // Konfigurasi tampilan status bar sistem
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.navBarBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
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

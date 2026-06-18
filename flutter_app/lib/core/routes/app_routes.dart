// lib/core/routes/app_routes.dart
//
// Definisi routing terpusat menggunakan package go_router.
// Seluruh navigasi antar halaman dikontrol dari file ini.
// Named routes menggunakan konstanta string untuk menghindari typo.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/screens/auth/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/signup_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/schedule/schedule_screen.dart';
import '../../presentation/screens/power/power_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/notification/notification_screen.dart';

// ---------------------------------------------------------------------------
// NAMA ROUTE (KONSTANTA)
// Gunakan konstanta ini setiap kali melakukan navigasi agar tidak typo.
// Contoh: context.goNamed(AppRouteNames.login)
// ---------------------------------------------------------------------------

class AppRouteNames {
  AppRouteNames._();

  static const String splash = 'splash';
  static const String login = 'login';
  static const String signup = 'signup';
  static const String dashboard = 'dashboard';
  static const String schedule = 'schedule';
  static const String power = 'power';
  static const String profile = 'profile';
  static const String notifications = 'notifications';
}

// ---------------------------------------------------------------------------
// PATH ROUTE
// ---------------------------------------------------------------------------

class AppRoutePaths {
  AppRoutePaths._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String schedule = '/schedule';
  static const String power = '/power';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
}

// ---------------------------------------------------------------------------
// KONFIGURASI GO_ROUTER
// ---------------------------------------------------------------------------

class AppRoutes {
  AppRoutes._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutePaths.splash,
    debugLogDiagnostics: false,
    routes: [
      // Splash Screen
      GoRoute(
        name: AppRouteNames.splash,
        path: AppRoutePaths.splash,
        pageBuilder: (context, state) => _buildPageWithFade(
          state: state,
          child: const SplashScreen(),
        ),
      ),

      // Login Screen
      GoRoute(
        name: AppRouteNames.login,
        path: AppRoutePaths.login,
        pageBuilder: (context, state) => _buildPageWithFade(
          state: state,
          child: const LoginScreen(),
        ),
      ),

      // Sign Up Screen
      GoRoute(
        name: AppRouteNames.signup,
        path: AppRoutePaths.signup,
        pageBuilder: (context, state) => _buildPageWithFade(
          state: state,
          child: const SignUpScreen(),
        ),
      ),

      // Dashboard Screen
      GoRoute(
        name: AppRouteNames.dashboard,
        path: AppRoutePaths.dashboard,
        pageBuilder: (context, state) => _buildPageWithFade(
          state: state,
          child: const DashboardScreen(),
        ),
      ),

      // Schedule Screen
      GoRoute(
        name: AppRouteNames.schedule,
        path: AppRoutePaths.schedule,
        pageBuilder: (context, state) => _buildPageWithSlide(
          state: state,
          child: const ScheduleScreen(),
        ),
      ),

      // Power Screen
      GoRoute(
        name: AppRouteNames.power,
        path: AppRoutePaths.power,
        pageBuilder: (context, state) => _buildPageWithSlide(
          state: state,
          child: const PowerScreen(),
        ),
      ),

      // Profile Screen
      GoRoute(
        name: AppRouteNames.profile,
        path: AppRoutePaths.profile,
        pageBuilder: (context, state) => _buildPageWithSlide(
          state: state,
          child: const ProfileScreen(),
        ),
      ),

      // Notification Screen
      // Menggunakan transisi slide dari kanan (push behavior), bukan tab switching.
      GoRoute(
        name: AppRouteNames.notifications,
        path: AppRoutePaths.notifications,
        pageBuilder: (context, state) => _buildPageWithSlideFromRight(
          state: state,
          child: const NotificationScreen(),
        ),
      ),
    ],

    // Handler error route tidak ditemukan
    errorPageBuilder: (context, state) => MaterialPage(
      child: Scaffold(
        backgroundColor: const Color(0xFFE8F5E2),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Color(0xFF2D7A27)),
              const SizedBox(height: 16),
              Text(
                'Halaman tidak ditemukan: ${state.uri}',
                style: const TextStyle(color: Color(0xFF757575)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // -------------------------------------------------------------------------
  // BUILDER HELPER: Transisi Fade
  // -------------------------------------------------------------------------
  static CustomTransitionPage _buildPageWithFade({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
          child: child,
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // BUILDER HELPER: Transisi Slide dari Bawah
  // -------------------------------------------------------------------------
  static CustomTransitionPage _buildPageWithSlide({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurveTween(curve: Curves.easeOut).animate(animation)),
          child: child,
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // BUILDER HELPER: Transisi Slide dari Kanan
  // Digunakan untuk halaman yang dipush (Notifikasi)
  // -------------------------------------------------------------------------
  static CustomTransitionPage _buildPageWithSlideFromRight({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurveTween(curve: Curves.easeOut).animate(animation)),
          child: child,
        );
      },
    );
  }
}

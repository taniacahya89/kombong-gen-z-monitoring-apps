// lib/presentation/screens/auth/splash_screen.dart
//
// Halaman Splash Screen.
//
// DESAIN (dari gambar referensi):
//   - Background: gambar peternakan dari assets/images/splash_bg.png
//   - Judul besar: "Kombong GenZ" (warna coklat tua, font bold)
//   - Subtitle: "Smart Monitoring for Smart Farming" (warna coklat medium)
//   - Tombol "Mulai": rounded, warna coklat tua
//
// CATATAN PENTING:
//   File assets/images/splash_bg.png WAJIB ada sebelum build.
//   Jika file tidak ada, fallback menggunakan warna background gradient.
//
// FLOW: Auto-navigate ke Login setelah 3 detik (via timer),
//       atau via tombol "Mulai".

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startTimer();
  }

  void _setupAnimations() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    // Mulai animasi masuk setelah delay singkat
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _animController.forward();
    });
  }

  void _startTimer() {
    // Tunggu authStateProvider selesai inisialisasi (cek token tersimpan),
    // lalu arahkan ke halaman yang tepat.
    _timer = Timer(AppDuration.splashTimer, () {
      if (!mounted) return;
      final authState = ref.read(authStateProvider);
      // Jika state masih loading, tetap tunggu — jangan paksa navigasi
      authState.whenOrNull(
        data: (user) {
          if (user != null) {
            // Token valid: langsung ke dashboard tanpa melalui login
            context.goNamed(AppRouteNames.dashboard);
          } else {
            context.goNamed(AppRouteNames.login);
          }
        },
        error: (_, __) => context.goNamed(AppRouteNames.login),
      );
    });
  }

  void _navigateToLogin() {
    _timer?.cancel();
    // Tombol "Mulai" selalu ke login — biarkan login screen yang handle redirect
    context.goNamed(AppRouteNames.login);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Background Gambar
          // Menggunakan Image.asset dengan fallback Container berwarna
          _buildBackground(),

          // Layer 2: Overlay gradient gelap di atas untuk keterbacaan teks
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000), // Transparan di atas
                  Color(0x20000000), // Sedikit gelap di tengah
                  Color(0x10000000), // Hampir transparan di bawah
                ],
              ),
            ),
          ),

          // Layer 3: Konten utama (teks dan tombol)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      // Judul Besar
                      Text(
                        'Kombong\nGenZ',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: AppColors.splashTitle,
                          fontFamily: AppAssets.fontFamily,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tagline
                      Text(
                        AppStrings.appTagline,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF7D5E3C),
                          fontFamily: AppAssets.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Tombol Mulai
                      GestureDetector(
                        onTap: _navigateToLogin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.splashButton,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: const Text(
                            AppStrings.splashButtonLabel,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontFamily: AppAssets.fontFamily,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    // Coba muat gambar dari assets. Jika tidak ada, gunakan gradient fallback.
    return Image.asset(
      AppAssets.splashBackground,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Fallback: gradient yang menyerupai nuansa pertanian hijau-kuning
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF5E6C8), // Langit: kuning krem
                Color(0xFFD4EDAA), // Perbukitan: hijau muda
                Color(0xFF8BC34A), // Ladang: hijau segar
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

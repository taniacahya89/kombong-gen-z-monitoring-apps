// lib/presentation/screens/auth/login_screen.dart
//
// Halaman Login.
//
// DESAIN (dari gambar referensi):
//   - Background: hijau muda pastel (#E8F5E2) memenuhi layar
//   - Kartu putih rounded di tengah dengan padding konten
//   - Judul: "Selamat Datang" (bold, hitam)
//   - Subtitle: "Masuk ke akun Anda untuk melanjutkan" (abu, regular)
//   - Field Email dan Password dengan label di atas
//   - Link "Lupa password?" (hijau, italic) rata kanan
//   - Tombol "Masuk" hijau tua, rounded pill, full width
//   - Footer: "Belum punya akun? Daftar" (Daftar = hijau, bold)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/providers/auth_provider.dart';
import '../../widgets/common/custom_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Panggil API login via authStateProvider — menyimpan token ke
      // secure storage dan memperbarui state global.
      await ref.read(authStateProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;

      // Cek apakah login berhasil (state berisi UserModel, bukan error)
      final authState = ref.read(authStateProvider);
      authState.when(
        data: (user) {
          if (user != null) {
            context.goNamed(AppRouteNames.dashboard);
          }
        },
        error: (e, _) {
          // Tampilkan pesan error dari backend (misal: "Email atau password tidak valid")
          final message = e.toString().replaceAll('Exception: ', '');
          AppUtils.showErrorSnackBar(context, message);
        },
        loading: () {},
      );
    } catch (e) {
      if (!mounted) return;
      AppUtils.showErrorSnackBar(
        context,
        'Tidak dapat terhubung ke server. Periksa koneksi jaringan.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Kartu Utama
                  _buildLoginCard(),

                  const SizedBox(height: 28),

                  // Footer: Navigasi ke Sign Up
                  _buildSignUpFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Judul
            Text(
              AppStrings.loginTitle,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle
            Text(
              AppStrings.loginSubtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
            const SizedBox(height: 28),

            // Field Email
            CustomTextField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              nextFocusNode: _passwordFocusNode,
              label: AppStrings.loginEmailLabel,
              hintText: AppStrings.loginEmailHint,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: AppUtils.validateEmail,
            ),
            const SizedBox(height: 20),

            // Field Password
            CustomTextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              label: AppStrings.loginPasswordLabel,
              hintText: AppStrings.loginPasswordHint,
              isPassword: true,
              textInputAction: TextInputAction.done,
              validator: AppUtils.validatePassword,
            ),
            const SizedBox(height: 12),

            // Link Lupa Password
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  // TODO (Fase 2): Navigasi ke halaman reset password
                  AppUtils.showSnackBar(context, 'Fitur lupa password akan segera tersedia');
                },
                child: Text(
                  AppStrings.loginForgotPassword,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textAccentGreen,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    fontFamily: AppAssets.fontFamily,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Tombol Masuk
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        AppStrings.loginButton,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppAssets.fontFamily,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppStrings.loginNoAccount,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontFamily: AppAssets.fontFamily,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => context.goNamed(AppRouteNames.signup),
          child: Text(
            AppStrings.loginRegisterLink,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              fontFamily: AppAssets.fontFamily,
            ),
          ),
        ),
      ],
    );
  }
}

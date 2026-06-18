// lib/presentation/screens/auth/signup_screen.dart
//
// Halaman Sign Up / Registrasi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/providers/auth_provider.dart';
import '../../widgets/common/custom_text_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameFocusNode = FocusNode();
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authStateProvider.notifier).register(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;

      final authState = ref.read(authStateProvider);
      authState.when(
        data: (user) {
          if (user != null) {
            // Registrasi berhasil — token sudah tersimpan, langsung ke dashboard
            context.goNamed(AppRouteNames.dashboard);
          }
        },
        error: (e, _) {
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

                  // Kartu Registrasi
                  _buildSignUpCard(),

                  const SizedBox(height: 28),

                  // Footer: Navigasi kembali ke Login
                  _buildLoginFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpCard() {
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
              AppStrings.signupTitle,
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
              AppStrings.signupSubtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
            const SizedBox(height: 28),

            // Field Nama Lengkap
            CustomTextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              nextFocusNode: _emailFocusNode,
              label: AppStrings.signupNameLabel,
              hintText: AppStrings.signupNameHint,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              validator: AppUtils.validateName,
            ),
            const SizedBox(height: 20),

            // Field Email
            CustomTextField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              nextFocusNode: _passwordFocusNode,
              label: AppStrings.signupEmailLabel,
              hintText: AppStrings.signupEmailHint,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: AppUtils.validateEmail,
            ),
            const SizedBox(height: 20),

            // Field Password
            CustomTextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              label: AppStrings.signupPasswordLabel,
              hintText: AppStrings.signupPasswordHint,
              isPassword: true,
              textInputAction: TextInputAction.done,
              validator: AppUtils.validatePassword,
            ),
            const SizedBox(height: 32),

            // Tombol Daftar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSignUp,
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
                        AppStrings.signupButton,
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

  Widget _buildLoginFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppStrings.signupHasAccount,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontFamily: AppAssets.fontFamily,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => context.goNamed(AppRouteNames.login),
          child: Text(
            AppStrings.signupLoginLink,
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

// lib/presentation/screens/profile/profile_screen.dart
//
// Halaman Profil - Informasi akun pengguna dan keamanan.
//
// Desain (dari gambar referensi):
//   - Header: judul "Profil" + subtitle "Informasi akun Anda."
//   - Kartu avatar: inisial nama + nama + label role (guest/warga)
//   - Kartu info: baris EMAIL dan baris "Keamanan Akun"
//   - Tombol Logout (merah, full-width, outlined)
//   - Bottom Navigation Bar: item Profil aktif
//
// Fitur Keamanan Akun:
//   Menekan "Keamanan Akun" membuka ChangePasswordScreen yang ditampilkan
//   sebagai bottom sheet modal.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../data/models/user_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.profilePageTitle,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: AppAssets.fontFamily,
                        ),
                      ),
                      Text(
                        AppStrings.profileSubtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: AppAssets.fontFamily,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),

            // Konten scrollable
            Expanded(
              child: authState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Gagal memuat profil: $e',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: AppAssets.fontFamily,
                    ),
                  ),
                ),
                data: (user) {
                  if (user == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      context.goNamed(AppRouteNames.login);
                    });
                    return const SizedBox.shrink();
                  }
                  return _buildContent(context, ref, user);
                },
              ),
            ),

            // Bottom Nav
            _buildBottomNavBar(context, 3),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          // Kartu Avatar dan Nama
          _buildAvatarCard(user),
          const SizedBox(height: 16),

          // Kartu Informasi
          _buildInfoCard(context, ref, user),
          const SizedBox(height: 32),

          // Tombol Logout
          _buildLogoutButton(context, ref),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KARTU AVATAR
  // ---------------------------------------------------------------------------

  Widget _buildAvatarCard(UserModel user) {
    // Ambil inisial dari nama (misalnya "Budi Santoso" -> "BS")
    final nameParts = (user.name ?? user.email).trim().split(' ');
    final initials = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : nameParts[0].substring(0, nameParts[0].length.clamp(0, 2)).toUpperCase();

    final roleLabel = user.isWarga
        ? AppStrings.profileRoleWarga
        : AppStrings.profileRoleGuest;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Avatar lingkaran dengan inisial
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontFamily: AppAssets.fontFamily,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Nama dan role
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name ?? 'Pengguna',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: AppAssets.fontFamily,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: user.isWarga
                      ? AppColors.primaryContainer
                      : const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  roleLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: user.isWarga
                        ? AppColors.primary
                        : const Color(0xFF7B1FA2),
                    fontFamily: AppAssets.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KARTU INFORMASI (EMAIL + KEAMANAN AKUN)
  // ---------------------------------------------------------------------------

  Widget _buildInfoCard(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Baris Email
          _buildInfoRow(
            icon: Icons.email_outlined,
            topLabel: AppStrings.profileEmailLabel,
            bottomLabel: user.email,
            onTap: null,
          ),

          const Divider(height: 1, indent: 20, endIndent: 20),

          // Baris Keamanan Akun
          _buildInfoRow(
            icon: Icons.lock_outline_rounded,
            topLabel: null,
            bottomLabel: AppStrings.profileSecurityLabel,
            onTap: () => _showChangePasswordSheet(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    String? topLabel,
    required String bottomLabel,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.inputFill,
              ),
              child: Icon(icon, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (topLabel != null) ...[
                    Text(
                      topLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                        fontFamily: AppAssets.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    bottomLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      fontFamily: AppAssets.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOMBOL LOGOUT
  // ---------------------------------------------------------------------------

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            title: const Text(
              'Konfirmasi Logout',
              style: TextStyle(
                fontFamily: AppAssets.fontFamily,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'Apakah Anda yakin ingin keluar dari akun ini?',
              style: TextStyle(fontFamily: AppAssets.fontFamily),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Batal',
                  style: TextStyle(fontFamily: AppAssets.fontFamily),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textAccentRed,
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    fontFamily: AppAssets.fontFamily,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await ref.read(authStateProvider.notifier).logout();
          if (context.mounted) {
            context.goNamed(AppRouteNames.login);
          }
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textAccentRed,
        side: const BorderSide(color: AppColors.textAccentRed, width: 1.5),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        backgroundColor: const Color(0xFFFFF0F0),
      ),
      icon: const Icon(Icons.logout_rounded, size: 20),
      label: const Text(
        AppStrings.profileLogoutButton,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          fontFamily: AppAssets.fontFamily,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM SHEET UBAH KATA SANDI
  // ---------------------------------------------------------------------------

  void _showChangePasswordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChangePasswordSheet(ref: ref),
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM NAVIGATION BAR
  // ---------------------------------------------------------------------------

  Widget _buildBottomNavBar(BuildContext context, int activeIndex) {
    final items = [
      (Icons.dashboard_outlined, Icons.dashboard, AppStrings.navDashboard, AppRouteNames.dashboard),
      (Icons.schedule_outlined, Icons.schedule, AppStrings.navSchedule, AppRouteNames.schedule),
      (Icons.bolt_outlined, Icons.bolt, AppStrings.navPower, AppRouteNames.power),
      (Icons.person_outline, Icons.person, AppStrings.navProfile, AppRouteNames.profile),
    ];

    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: AppColors.navBarBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [BoxShadow(color: Color(0x30000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final isActive = index == activeIndex;
          final item = items[index];
          return GestureDetector(
            onTap: () {
              if (!isActive) context.goNamed(item.$4);
            },
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 70,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: AppDuration.short,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primaryLight.withOpacity(0.3)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isActive ? item.$2 : item.$1,
                      color: isActive ? AppColors.navBarActive : AppColors.navBarInactive,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.$3,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? AppColors.navBarActive : AppColors.navBarInactive,
                      fontFamily: AppAssets.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BOTTOM SHEET UBAH KATA SANDI
// Dipisahkan sebagai StatefulWidget karena memiliki state lokal (controller,
// loading indicator, dan visibility toggle untuk password field).
// ---------------------------------------------------------------------------

class _ChangePasswordSheet extends StatefulWidget {
  final WidgetRef ref;
  const _ChangePasswordSheet({required this.ref});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await widget.ref.read(authStateProvider.notifier).changePassword(
            oldPassword: _oldPasswordController.text,
            newPassword: _newPasswordController.text,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password berhasil diubah'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('401') || e.toString().contains('lama')
                  ? 'Password lama tidak sesuai'
                  : 'Gagal mengubah password: $e',
            ),
            backgroundColor: AppColors.textAccentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Judul
            const Text(
              AppStrings.changePasswordTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
            const SizedBox(height: 20),

            // Field Password Lama
            TextFormField(
              controller: _oldPasswordController,
              obscureText: !_showOld,
              decoration: InputDecoration(
                labelText: AppStrings.changePasswordOld,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showOld ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _showOld = !_showOld),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Password lama tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Field Password Baru
            TextFormField(
              controller: _newPasswordController,
              obscureText: !_showNew,
              decoration: InputDecoration(
                labelText: AppStrings.changePasswordNew,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Password baru tidak boleh kosong';
                }
                if (v.length < 8) return 'Password minimal 8 karakter';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Field Konfirmasi Password
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirm,
              decoration: InputDecoration(
                labelText: AppStrings.changePasswordConfirm,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                ),
              ),
              validator: (v) {
                if (v != _newPasswordController.text) {
                  return AppStrings.errorPasswordMismatch;
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Tombol simpan
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(AppStrings.changePasswordButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

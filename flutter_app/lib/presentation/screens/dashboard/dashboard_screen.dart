// lib/presentation/screens/dashboard/dashboard_screen.dart
//
// Halaman Dashboard - Halaman utama setelah login.
//
// DESAIN (dari gambar referensi):
//   - Background: hijau muda (#E8F5E2)
//   - Header: Avatar lingkaran kiri + nama "Kombong Gen Z" + "Selamat Datang, User" (User merah)
//   - Kartu Water Tank: visualisasi level + nilai cm + status
//   - Kartu Next Schedule: dua kolom jadwal (Pakan Ayam & Minum Ayam) dalam kotak abu
//   - Kartu Live Energy: tiga metrik (Current, Voltage, Power) dengan sparkline
//   - Bottom Navigation Bar: hijau tua, 4 item (Dashboard, Jadwal Pakan, Daya, Profil)
//     Item Dashboard aktif = icon bulat hijau muda
//
// FLOW: Tab navigasi bawah -> masing-masing halaman
// DATA: Menggunakan Riverpod untuk mengambil data real-time dan status luring alat.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/dashboard_provider.dart';
import '../../../core/providers/schedule_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../widgets/dashboard/water_tank_card.dart';
import '../../widgets/dashboard/schedule_card.dart';
import '../../widgets/dashboard/energy_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }


  void _onNavItemTapped(int index) {
    if (index == _currentNavIndex) return;

    switch (index) {
      case 0:
        // Sudah di Dashboard
        break;
      case 1:
        context.goNamed(AppRouteNames.schedule);
        break;
      case 2:
        context.goNamed(AppRouteNames.power);
        break;
      case 3:
        context.goNamed(AppRouteNames.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Data User
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final userName = user?.name ?? 'User';

    // 1b. Data Notifikasi untuk badge lonceng
    final notificationState = ref.watch(notificationProvider);
    final unreadCount = notificationState.unreadCount;

    // 2. Data Sensor Tangki Air (FutureProvider)
    final waterTankAsync = ref.watch(waterTankProvider);
    final waterTankWidget = waterTankAsync.when(
      data: (data) => WaterTankCard(data: data),
      error: (err, _) => Card(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Gagal memuat data tangki air: $err', style: const TextStyle(color: AppColors.textAccentRed)),
        ),
      ),
      loading: () => waterTankAsync.valueOrNull != null
          ? WaterTankCard(data: waterTankAsync.valueOrNull!)
          : const Card(
              child: SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ),
    );

    // 3. Data Sensor Kelistrikan (FutureProvider)
    final solarAsync = ref.watch(solarLatestDashboardProvider);
    final solarWidget = solarAsync.when(
      data: (data) => EnergyCard(data: data),
      error: (err, _) => Card(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Gagal memuat data energi: $err', style: const TextStyle(color: AppColors.textAccentRed)),
        ),
      ),
      loading: () => solarAsync.valueOrNull != null
          ? EnergyCard(data: solarAsync.valueOrNull!)
          : const Card(
              child: SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ),
    );

    // 4. Data Jadwal Pakan (StateNotifierProvider)
    final scheduleState = ref.watch(scheduleProvider);
    final scheduleWidget = scheduleState.when(
      data: (list) => ScheduleCard(schedules: list),
      error: (err, _) => Card(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Gagal memuat jadwal: $err', style: const TextStyle(color: AppColors.textAccentRed)),
        ),
      ),
      loading: () => scheduleState.valueOrNull != null
          ? ScheduleCard(schedules: scheduleState.valueOrNull!)
          : const Card(
              child: SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ),
    );

    // 5. Data Status Koneksi Alat (FutureProvider)
    final statusAsync = ref.watch(deviceStatusProvider);
    Widget? statusBanner;
    if (statusAsync.hasValue) {
      final statusMap = statusAsync.value!;
      final status = statusMap['status'] as String? ?? 'online';
      final message = statusMap['message'] as String? ?? '';
      final minutes = statusMap['minutes_since_last_data'] as int? ?? 0;

      if (status == 'offline') {
        statusBanner = Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.textAccentRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.textAccentRed.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: AppColors.textAccentRed, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Alat luring: data terakhir dikirim $minutes menit yang lalu. $message',
                  style: const TextStyle(
                    color: AppColors.textAccentRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppAssets.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (status == 'server_mqtt_disconnected') {
        statusBanner = Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.accentOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.cloud_off, color: AppColors.accentOrange, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Server MQTT terputus. Backend sedang mencoba menghubungkan kembali.',
                  style: TextStyle(
                    color: AppColors.accentOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppAssets.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (status == 'no_data') {
        statusBanner = Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Belum ada data sensor masuk dari perangkat. Pastikan alat sudah menyala.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppAssets.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _buildHeader(userName, unreadCount),
              ),
            ),

            // Konten Utama
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (statusBanner != null) statusBanner,

                  // Kartu Water Tank
                  waterTankWidget,
                  const SizedBox(height: 16),

                  // Kartu Next Schedule
                  scheduleWidget,
                  const SizedBox(height: 16),

                  // Kartu Live Energy
                  solarWidget,
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // -------------------------------------------------------------------------
  // WIDGET HEADER DASHBOARD
  // Menampilkan avatar, nama farm, dan greeting dengan nama user
  // -------------------------------------------------------------------------
  Widget _buildHeader(String userName, int unreadCount) {
    return Row(
      children: [
        // Avatar Bulat
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryContainer,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: ClipOval(
            child: Image.asset(
              AppAssets.avatarDefault,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback: Icon pengguna
                return const Icon(
                  Icons.person,
                  color: AppColors.primary,
                  size: 28,
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Nama Farm + Greeting
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.dashboardFarmName,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: AppAssets.fontFamily,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppAssets.fontFamily,
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    const TextSpan(text: '${AppStrings.dashboardGreeting} '),
                    TextSpan(
                      text: userName,
                      style: const TextStyle(
                        color: AppColors.textAccentRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Tombol notifikasi - menuju halaman Notifikasi
        IconButton(
          onPressed: () {
            context.goNamed(AppRouteNames.notifications);
          },
          icon: unreadCount > 0
              ? Badge(
                  label: Text('$unreadCount'),
                  backgroundColor: AppColors.textAccentRed,
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.textSecondary,
                  ),
                )
              : const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.textSecondary,
                ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // BOTTOM NAVIGATION BAR
  // Desain: background hijau tua, item aktif dalam lingkaran hijau muda
  // -------------------------------------------------------------------------

  Widget _buildBottomNavBar() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: AppColors.navBarBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            index: 0,
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
            label: AppStrings.navDashboard,
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.schedule_outlined,
            activeIcon: Icons.schedule,
            label: AppStrings.navSchedule,
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.bolt_outlined,
            activeIcon: Icons.bolt,
            label: AppStrings.navPower,
          ),
          _buildNavItem(
            index: 3,
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: AppStrings.navProfile,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = _currentNavIndex == index;

    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon: bulat hijau muda jika aktif
            AnimatedContainer(
              duration: AppDuration.short,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryLight.withValues(alpha: 0.3)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive
                    ? AppColors.navBarActive
                    : AppColors.navBarInactive,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),

            // Label
            Text(
              label,
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
  }
}

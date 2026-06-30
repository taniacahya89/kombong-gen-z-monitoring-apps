// lib/presentation/screens/schedule/schedule_screen.dart
//
// Halaman Jadwal Pakan - Manajemen jadwal pakan ayam.
//
// Desain:
//   - Header: judul + subtitle
//   - Banner panduan nutrisi (akses ke FeedNutritionScreen)
//   - Kartu jadwal berikutnya
//   - Section kartu: "Pakan Ayam"
//   - Water Status Card: status ketersediaan air minum real-time (dari sensor)
//   - FAB tambah jadwal baru
//   - RBAC: Jika role guest, FAB dan tombol aksi disembunyikan/disabled
//
// State management:
//   - scheduleProvider: daftar jadwal pakan
//   - waterAlertProvider: status sensor air minum + logika notifikasi

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/providers/schedule_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/water_alert_provider.dart';
import '../../../core/utils/app_utils.dart';
import '../../../data/models/feeding_schedule_model.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleState = ref.watch(scheduleProvider);
    final authState = ref.watch(authStateProvider);

    // Ambil role user dari auth state; default ke guest jika belum login
    final userRole = authState.valueOrNull?.role ?? 'guest';
    final canEdit = userRole == 'warga';

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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.schedulePageTitle,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: AppAssets.fontFamily,
                        ),
                      ),
                      Text(
                        AppStrings.schedulePageSubtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: AppAssets.fontFamily,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () =>
                        ref.read(scheduleProvider.notifier).loadSchedules(),
                  ),
                ],
              ),
            ),

            // Banner peringatan untuk user guest
            if (!canEdit)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: const Color(0xFFFFCC80)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: Color(0xFFEF6C00)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppStrings.scheduleGuestWarning,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEF6C00),
                          fontFamily: AppAssets.fontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Konten scrollable
            Expanded(
              child: scheduleState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.textHint, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Gagal memuat jadwal',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: AppAssets.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () =>
                            ref.read(scheduleProvider.notifier).loadSchedules(),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
                data: (schedules) {
                  final notifier = ref.read(scheduleProvider.notifier);
                  final nextSchedule = notifier.nextSchedule;
                  final pakanList = notifier.pakanSchedules;

                  return RefreshIndicator(
                    onRefresh: () => notifier.loadSchedules(),
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      child: Column(
                        children: [
                          // Banner Panduan Nutrisi
                          _buildNutritionGuideBanner(context),
                          const SizedBox(height: 16),

                          // Kartu Jadwal Berikutnya
                          if (nextSchedule != null)
                            _buildNextScheduleCard(nextSchedule),
                          if (nextSchedule != null) const SizedBox(height: 16),

                          // Section Pakan Ayam
                          if (pakanList.isNotEmpty) ...[
                            _buildScheduleSection(
                              context: context,
                              ref: ref,
                              title: AppStrings.scheduleSectionPakan,
                              schedules: pakanList,
                              canEdit: canEdit,
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (pakanList.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(Icons.schedule_outlined,
                                      size: 64, color: AppColors.textHint),
                                  SizedBox(height: 16),
                                  Text(
                                    'Belum ada jadwal pakan',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontFamily: AppAssets.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Water Status Card — selalu tampil di bawah
                          _buildWaterStatusCard(ref),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Nav
            _buildBottomNavBar(context, 1),
          ],
        ),
      ),

      // FAB hanya tampil untuk user warga
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _showScheduleFormDialog(context, ref),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Tambah',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: AppAssets.fontFamily,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // KARTU JADWAL BERIKUTNYA
  // ---------------------------------------------------------------------------

  Widget _buildNextScheduleCard(FeedingScheduleModel next) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.scheduleNextLabel,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontFamily: AppAssets.fontFamily,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            next.time,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: AppAssets.fontFamily,
              letterSpacing: -1,
            ),
          ),
          Text(
            next.label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontFamily: AppAssets.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WATER STATUS CARD
  // ---------------------------------------------------------------------------

  Widget _buildWaterStatusCard(WidgetRef ref) {
    final waterAlert = ref.watch(waterAlertProvider);

    // Tentukan warna berdasarkan kondisi kritis
    final Color statusColor = waterAlert.isCritical
        ? AppColors.textAccentRed
        : AppColors.primary;
    final Color statusBgColor = waterAlert.isCritical
        ? const Color(0xFFFFEBEE) // merah sangat muda
        : AppColors.primaryContainer;
    final Color borderColor = waterAlert.isCritical
        ? const Color(0xFFEF9A9A)
        : AppColors.primaryLight.withValues(alpha: 0.4);

    final String statusLabel = waterAlert.isCritical
        ? AppStrings.waterStatusCritical
        : AppStrings.waterStatusSafe;
    final String statusSub = waterAlert.isCritical
        ? AppStrings.waterStatusSubCritical
        : AppStrings.waterStatusSubSafe;
    final IconData statusIcon = waterAlert.isCritical
        ? Icons.warning_amber_rounded
        : Icons.water_drop_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris judul + ikon status
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppStrings.waterStatusTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontFamily: AppAssets.fontFamily,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        fontFamily: AppAssets.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),

              // Badge persentase level
              if (waterAlert.levelPercentage != null && !waterAlert.isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '${(waterAlert.levelPercentage! * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      fontFamily: AppAssets.fontFamily,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar level air
          if (!waterAlert.isLoading && waterAlert.levelPercentage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: waterAlert.levelPercentage,
                minHeight: 8,
                backgroundColor: AppColors.inputFill,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 8),

            // Informasi detail ketinggian
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppUtils.formatSensorValue(waterAlert.currentHeightCm ?? 0)} cm'
                  ' / ${AppUtils.formatSensorValue(waterAlert.maxCapacityCm ?? 0)} cm',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontFamily: AppAssets.fontFamily,
                  ),
                ),
                Text(
                  AppUtils.getWaterTankStatus(waterAlert.levelPercentage!),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppUtils.getWaterTankStatusColor(waterAlert.levelPercentage!),
                    fontFamily: AppAssets.fontFamily,
                  ),
                ),
              ],
            ),
          ],

          if (waterAlert.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: AppColors.inputFill,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),

          const SizedBox(height: 10),

          // Teks keterangan
          Text(
            statusSub,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontFamily: AppAssets.fontFamily,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BANNER PANDUAN NUTRISI
  // ---------------------------------------------------------------------------

  Widget _buildNutritionGuideBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(AppRouteNames.feedNutrition),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 8,
                offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.feedNutritionBannerLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: AppAssets.fontFamily,
                    ),
                  ),
                  Text(
                    AppStrings.feedNutritionBannerSub,
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xD9FFFFFF), // Colors.white at 85% opacity
                      fontFamily: AppAssets.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION DAFTAR JADWAL
  // ---------------------------------------------------------------------------

  Widget _buildScheduleSection({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required List<FeedingScheduleModel> schedules,
    required bool canEdit,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: AppAssets.fontFamily,
            ),
          ),
          const SizedBox(height: 12),
          ...schedules.map(
            (schedule) => _buildScheduleItem(
              context: context,
              ref: ref,
              schedule: schedule,
              canEdit: canEdit,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ITEM JADWAL INDIVIDUAL
  // ---------------------------------------------------------------------------

  Widget _buildScheduleItem({
    required BuildContext context,
    required WidgetRef ref,
    required FeedingScheduleModel schedule,
    required bool canEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            // Indikator aktif (lingkaran berwarna)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: schedule.isActive ? AppColors.primary : AppColors.textHint,
              ),
            ),
            const SizedBox(width: 12),

            // Informasi jadwal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: AppAssets.fontFamily,
                    ),
                  ),
                  Text(
                    schedule.time,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontFamily: AppAssets.fontFamily,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle dan tombol aksi (hanya untuk warga dengan jadwal pakan)
            // Jadwal minum tidak dapat diubah oleh siapapun melalui UI maupun API.
            if (canEdit && schedule.feedType == 'pakan') ...[
              Switch(
                value: schedule.isActive,
                onChanged: (value) async {
                  try {
                    await ref.read(scheduleProvider.notifier).updateSchedule(
                          schedule.copyWith(isActive: value),
                        );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal memperbarui: $e')),
                      );
                    }
                  }
                },
                activeThumbColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.textSecondary),
                onPressed: () =>
                    _showScheduleFormDialog(context, ref, schedule: schedule),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.textAccentRed),
                onPressed: () => _confirmDelete(context, ref, schedule),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ] else ...[
              // Hanya tampilkan badge status untuk user guest
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: schedule.isActive
                      ? AppColors.primaryContainer
                      : AppColors.inputFill,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  schedule.isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: schedule.isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontFamily: AppAssets.fontFamily,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DIALOG FORM TAMBAH / EDIT JADWAL
  // ---------------------------------------------------------------------------

  void _showScheduleFormDialog(
    BuildContext context,
    WidgetRef ref, {
    FeedingScheduleModel? schedule,
  }) {
    final isEditing = schedule != null;
    final labelController = TextEditingController(text: schedule?.label ?? '');
    String selectedTime = schedule?.time ?? '08:00';
    String selectedFeedType = schedule?.feedType ?? 'pakan';
    bool isActive = schedule?.isActive ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          title: Text(
            isEditing ? 'Edit Jadwal' : 'Tambah Jadwal',
            style: const TextStyle(
              fontFamily: AppAssets.fontFamily,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nama jadwal
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Jadwal',
                    hintText: 'Contoh: Pakan Pagi',
                  ),
                ),
                const SizedBox(height: 16),

                // Pilih waktu
                GestureDetector(
                  onTap: () async {
                    final parts = selectedTime.split(':');
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(
                        hour: int.parse(parts[0]),
                        minute: int.parse(parts[1]),
                      ),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedTime =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: AppColors.textSecondary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          selectedTime,
                          style: const TextStyle(
                            fontFamily: AppAssets.fontFamily,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tipe pakan
                // Pilihan "Minum" dinonaktifkan: jadwal minum tidak dapat dibuat
                // atau diubah melalui UI. Ini mencerminkan aturan bisnis yang sama
                // yang diterapkan di layer backend.
                Row(
                  children: [
                    const Text('Tipe:', style: TextStyle(fontFamily: AppAssets.fontFamily)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Pakan'),
                      selected: selectedFeedType == 'pakan',
                      onSelected: (_) =>
                          setDialogState(() => selectedFeedType = 'pakan'),
                      selectedColor: AppColors.primaryContainer,
                      labelStyle: TextStyle(
                        fontFamily: AppAssets.fontFamily,
                        color: selectedFeedType == 'pakan'
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chip "Minum" ditampilkan tapi tidak dapat dipilih
                    const Tooltip(
                      message: 'Jadwal minum tidak dapat dikelola',
                      child: ChoiceChip(
                        label: Text('Minum'),
                        selected: false,
                        onSelected: null, // null = disabled
                        disabledColor: AppColors.inputFill,
                        labelStyle: TextStyle(
                          fontFamily: AppAssets.fontFamily,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status aktif
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Aktifkan Jadwal',
                      style: TextStyle(fontFamily: AppAssets.fontFamily),
                    ),
                    Switch(
                      value: isActive,
                      onChanged: (v) => setDialogState(() => isActive = v),
                      activeThumbColor: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Batal',
                style: TextStyle(
                  fontFamily: AppAssets.fontFamily,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (labelController.text.trim().isEmpty) return;

                final newSchedule = FeedingScheduleModel(
                  firestoreId: schedule?.firestoreId ?? '',
                  label: labelController.text.trim(),
                  time: selectedTime,
                  feedType: selectedFeedType,
                  isActive: isActive,
                );

                Navigator.pop(dialogContext);

                try {
                  if (isEditing) {
                    await ref
                        .read(scheduleProvider.notifier)
                        .updateSchedule(newSchedule);
                  } else {
                    await ref
                        .read(scheduleProvider.notifier)
                        .createSchedule(newSchedule);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().contains('403')
                              ? 'Akses ditolak: hanya warga yang dapat mengelola jadwal'
                              : 'Gagal menyimpan jadwal: $e',
                        ),
                        backgroundColor: AppColors.textAccentRed,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                isEditing ? 'Simpan' : 'Tambah',
                style: const TextStyle(
                  fontFamily: AppAssets.fontFamily,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KONFIRMASI HAPUS
  // ---------------------------------------------------------------------------

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FeedingScheduleModel schedule,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Text(
          'Hapus Jadwal',
          style: TextStyle(
            fontFamily: AppAssets.fontFamily,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Yakin ingin menghapus "${schedule.label}"?',
          style: const TextStyle(
            fontFamily: AppAssets.fontFamily,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontFamily: AppAssets.fontFamily,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(scheduleProvider.notifier)
                    .deleteSchedule(schedule.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textAccentRed,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Hapus',
              style: TextStyle(fontFamily: AppAssets.fontFamily, color: Colors.white),
            ),
          ),
        ],
      ),
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
                          ? AppColors.primaryLight.withValues(alpha: 0.3)
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

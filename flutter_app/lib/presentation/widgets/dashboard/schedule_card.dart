// lib/presentation/widgets/dashboard/schedule_card.dart
//
// Widget kartu Next Schedule untuk halaman Dashboard.
// Menampilkan jadwal pakan berikutnya dalam dua kolom:
//   - PAKAN AYAM: jam pakan berikutnya yang aktif
//   - MINUM AYAM: jam minum berikutnya yang aktif
//
// Desain referensi: kartu abu-abu muda dengan label all-caps kecil
// dan nilai jam yang besar dan tebal (08.00 style).

import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/feeding_schedule_model.dart';
import '../../../core/utils/app_utils.dart';

class ScheduleCard extends StatelessWidget {
  final List<FeedingScheduleModel> schedules;

  const ScheduleCard({super.key, required this.schedules});

  // Ambil jadwal berikutnya yang aktif berdasarkan waktu sekarang, difilter per feed_type
  String _getNextTimeForType(String feedType) {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final filtered = schedules.where((s) => s.isActive && s.feedType == feedType).toList()
      ..sort((a, b) {
        final aParts = a.time.split(':');
        final bParts = b.time.split(':');
        final aMin = int.parse(aParts[0]) * 60 + int.parse(aParts[1]);
        final bMin = int.parse(bParts[0]) * 60 + int.parse(bParts[1]);
        return aMin.compareTo(bMin);
      });

    if (filtered.isEmpty) return '--:--';

    // Cari jadwal setelah waktu sekarang
    for (final s in filtered) {
      final parts = s.time.split(':');
      final scheduleMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      if (scheduleMinutes > nowMinutes) {
        return AppUtils.formatScheduleTime(s.time);
      }
    }

    // Semua sudah lewat hari ini — kembalikan yang pertama (jadwal besok)
    return AppUtils.formatScheduleTime(filtered.first.time);
  }

  @override
  Widget build(BuildContext context) {
    final nextPakanTime = _getNextTimeForType('pakan');
    final nextMinumTime = _getNextTimeForType('minum');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label header all-caps
          Text(
            AppStrings.nextScheduleTitle,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
              fontFamily: AppAssets.fontFamily,
            ),
          ),
          const SizedBox(height: 14),

          // Dua kolom jadwal
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _ScheduleItem(
                    label: AppStrings.scheduleChickenFeed,
                    time: nextPakanTime,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ScheduleItem(
                    label: AppStrings.scheduleChickenDrink,
                    time: nextMinumTime,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WIDGET ITEM JADWAL INDIVIDUAL
// ---------------------------------------------------------------------------

class _ScheduleItem extends StatelessWidget {
  final String label;
  final String time;

  const _ScheduleItem({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label kecil all-caps
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
              fontFamily: AppAssets.fontFamily,
            ),
          ),
          const SizedBox(height: 6),

          // Jam besar
          Text(
            time,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: AppAssets.fontFamily,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

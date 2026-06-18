// lib/presentation/screens/notification/notification_screen.dart
//
// Halaman Notifikasi - Riwayat peringatan sistem.
//
// Dipanggil dari: icon lonceng di header Dashboard.
// Navigasi: push (bukan tab), sehingga menggunakan AppBar dengan tombol back.
//
// Desain:
//   - AppBar minimal dengan judul dan tombol "Tandai Semua Dibaca"
//   - ListView notifikasi dengan card per item
//   - Badge unread (lingkaran hijau) pada item yang belum dibaca
//   - State kosong jika tidak ada notifikasi
//   - Timestamp relatif (misalnya "2 jam yang lalu")

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../data/models/notification_model.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.notifPageTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
            Text(
              AppStrings.notifPageSubtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
          ],
        ),
        toolbarHeight: 72,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).markAllRead(),
              child: const Text(
                AppStrings.notifMarkAllRead,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontFamily: AppAssets.fontFamily,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NotificationState state,
  ) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_off_outlined,
                size: 64, color: AppColors.textHint),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat notifikasi',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).loadNotifications(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              AppStrings.notifEmpty,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Semua sistem berjalan normal.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationProvider.notifier).loadNotifications(),
      color: AppColors.primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: state.notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return _buildNotificationCard(
            context,
            ref,
            state.notifications[index],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KARTU NOTIFIKASI INDIVIDUAL
  // ---------------------------------------------------------------------------

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notif,
  ) {
    return GestureDetector(
      onTap: () async {
        // Tandai sebagai dibaca terlebih dahulu sebelum navigasi
        if (!notif.isRead) {
          ref.read(notificationProvider.notifier).markRead(notif.id);
        }

        // Jika notifikasi terkait dengan halaman tertentu, navigasi langsung ke sana.
        // Jika tidak ada halaman yang relevan, tampilkan dialog detail saja.
        final destination = notif.destinationRoute;
        if (destination != null && context.mounted) {
          // go() menggantikan stack navigasi saat ini sehingga tombol back
          // tidak kembali ke halaman notifikasi — perilaku yang diinginkan
          // karena user sudah mendapatkan informasi lengkap dari halaman tujuan.
          context.go(destination);
        } else {
          _showNotificationDetail(context, notif);
        }
      },
      child: AnimatedOpacity(
        opacity: notif.isRead ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notif.isRead ? AppColors.surface : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: notif.isRead ? AppColors.divider : AppColors.primaryLight,
              width: notif.isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: notif.isRead
                    ? AppColors.shadow
                    : AppColors.primary.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ikon notifikasi dengan badge unread
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: notif.isRead
                          ? AppColors.inputFill
                          : AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getNotifIcon(notif.title),
                      size: 20,
                      color: notif.isRead ? AppColors.textSecondary : AppColors.primary,
                    ),
                  ),
                  if (!notif.isRead)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Konten teks
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: AppAssets.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFamily: AppAssets.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatRelativeTime(notif.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                        fontFamily: AppAssets.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DIALOG DETAIL NOTIFIKASI
  // ---------------------------------------------------------------------------

  void _showNotificationDetail(BuildContext context, NotificationModel notif) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer,
              ),
              child: Icon(
                _getNotifIcon(notif.title),
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                notif.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppAssets.fontFamily,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notif.body,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              DateFormat('dd MMM yyyy, HH:mm').format(notif.createdAt.toLocal()),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Tutup',
              style: TextStyle(
                fontFamily: AppAssets.fontFamily,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER: Ikon berdasarkan judul notifikasi
  // ---------------------------------------------------------------------------

  IconData _getNotifIcon(String title) {
    final titleLower = title.toLowerCase();
    if (titleLower.contains('air') || titleLower.contains('tangki')) {
      return Icons.water_drop_outlined;
    } else if (titleLower.contains('listrik') ||
        titleLower.contains('daya') ||
        titleLower.contains('tegangan')) {
      return Icons.bolt_outlined;
    } else if (titleLower.contains('pakan') || titleLower.contains('jadwal')) {
      return Icons.food_bank_outlined;
    }
    return Icons.notifications_outlined;
  }

  // ---------------------------------------------------------------------------
  // HELPER: Format waktu relatif
  // ---------------------------------------------------------------------------

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime.toLocal());

    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit yang lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam yang lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari yang lalu';

    return DateFormat('dd MMM yyyy').format(dateTime.toLocal());
  }
}

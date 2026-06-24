// lib/presentation/screens/schedule/feed_nutrition_screen.dart
//
// Halaman detail Panduan Nutrisi Pakan Ayam.
//
// UI/UX Pattern:
//   - Top Tab Bar  : pemisah antara Jadwal Pagi dan Jadwal Sore
//   - Card per kelompok umur dengan hierarki visual:
//       1. Heading  : label usia (tebal)
//       2. Porsi    : badge berwarna primer, menarik perhatian langsung
//       3. Komposisi: bullet list vertikal, mudah dipindai
//       4. Keterangan: secondary text, ukuran lebih kecil, warna abu
//
// State management:
//   - Hanya membutuhkan TabController bawaan Flutter (StatefulWidget).
//   - Tidak ada provider karena data bersifat statis (FeedNutritionData).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/feed_nutrition_model.dart';

class FeedNutritionScreen extends StatefulWidget {
  const FeedNutritionScreen({super.key});

  @override
  State<FeedNutritionScreen> createState() => _FeedNutritionScreenState();
}

class _FeedNutritionScreenState extends State<FeedNutritionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: FeedNutritionData.schedules.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // -----------------------------------------------------------------
            // HEADER
            // -----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
              child: Row(
                children: [
                  // Tombol kembali
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary, size: 20),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.feedNutritionPageTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: AppAssets.fontFamily,
                        ),
                      ),
                      Text(
                        AppStrings.feedNutritionPageSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: AppAssets.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // -----------------------------------------------------------------
            // TOP TAB BAR
            // -----------------------------------------------------------------
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.textOnPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontFamily: AppAssets.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: AppAssets.fontFamily,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: FeedNutritionData.schedules
                    .map((s) => Tab(text: s.timeLabel.split(' ').take(2).join(' ')))
                    .toList(),
              ),
            ),

            const SizedBox(height: 16),

            // -----------------------------------------------------------------
            // TAB VIEW KONTEN
            // -----------------------------------------------------------------
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: FeedNutritionData.schedules
                    .map((schedule) => _buildScheduleTab(schedule))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KONTEN SATU TAB (PAGI / SORE)
  // ---------------------------------------------------------------------------

  Widget _buildScheduleTab(FeedNutritionSchedule schedule) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      itemCount: schedule.ageGroups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) =>
          _buildAgeGroupCard(schedule.ageGroups[index]),
    );
  }

  // ---------------------------------------------------------------------------
  // CARD SATU KELOMPOK UMUR
  // ---------------------------------------------------------------------------

  Widget _buildAgeGroupCard(FeedNutritionAgeGroup group) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -----------------------------------------------------------------
          // BARIS 1: Judul kelompok umur + badge porsi
          // -----------------------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ikon umur
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.egg_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),

              // Label umur
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Umur ${group.ageLabel}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: AppAssets.fontFamily,
                      ),
                    ),
                    const Text(
                      'Kelompok umur ayam',
                      style: TextStyle(
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

          const SizedBox(height: 14),

          // -----------------------------------------------------------------
          // BARIS 2: Badge Porsi yang menonjol
          // -----------------------------------------------------------------
          _buildPorsiRow(group.porsi),

          const SizedBox(height: 14),

          // Divider tipis
          Container(height: 1, color: AppColors.divider),

          const SizedBox(height: 14),

          // -----------------------------------------------------------------
          // BARIS 3: Komposisi (bullet list)
          // -----------------------------------------------------------------
          _buildSectionLabel(AppStrings.feedNutritionKomposisiLabel,
              Icons.science_outlined),
          const SizedBox(height: 8),
          ...group.komposisi.map((item) => _buildCompositionRow(item)),

          const SizedBox(height: 12),

          // -----------------------------------------------------------------
          // BARIS 4: Keterangan (secondary text)
          // -----------------------------------------------------------------
          _buildKeteranganBox(group.keterangan),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET HELPER: BADGE PORSI
  // ---------------------------------------------------------------------------

  Widget _buildPorsiRow(String porsi) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: const Text(
            AppStrings.feedNutritionPorsiLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textOnPrimary,
              fontFamily: AppAssets.fontFamily,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          porsi,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            fontFamily: AppAssets.fontFamily,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET HELPER: LABEL SEKSI (KOMPOSISI, DLL)
  // ---------------------------------------------------------------------------

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            fontFamily: AppAssets.fontFamily,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET HELPER: SATU BARIS KOMPOSISI
  // ---------------------------------------------------------------------------

  Widget _buildCompositionRow(String item) {
    // Pisah nama bahan dan berat pada spasi ganda yang menjadi pemisah
    final parts = item.trim().split(RegExp(r'\s{2,}'));
    final nama = parts.isNotEmpty ? parts[0].trim() : item;
    final berat = parts.length > 1 ? parts[1].trim() : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // Bullet dot
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
          ),
          // Nama bahan
          Expanded(
            child: Text(
              nama,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
          ),
          // Berat (rata kanan)
          if (berat.isNotEmpty)
            Text(
              berat,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET HELPER: BOX KETERANGAN
  // ---------------------------------------------------------------------------

  Widget _buildKeteranganBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: AppAssets.fontFamily,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// lib/presentation/widgets/dashboard/energy_card.dart
//
// Widget kartu Live Energy untuk halaman Dashboard.
// Menampilkan tiga metrik panel surya dalam tiga kolom:
//   - CURRENT (A) dengan mini sparkline hijau
//   - VOLTAGE (V) dengan mini sparkline merah
//   - POWER (W) dengan mini sparkline kuning
//
// Desain referensi: tiga sub-kartu abu-abu dengan label all-caps,
// nilai besar, unit kecil di bawah, dan garis tren mini di bawahnya.
// Implementasi sparkline menggunakan CustomPaint untuk menghindari
// dependensi chart library yang berat.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/solar_metrics_model.dart';

class EnergyCard extends StatelessWidget {
  final SolarMetricsModel data;

  const EnergyCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
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
          const Text(
            AppStrings.liveEnergyTitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
              fontFamily: AppAssets.fontFamily,
            ),
          ),
          const SizedBox(height: 14),

          // Tiga kolom metrik energi
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _EnergyMetricItem(
                    label: AppStrings.energyCurrent,
                    value: data.current.toStringAsFixed(1),
                    unit: AppStrings.energyUnitAmpere,
                    sparklineColor: AppColors.chartGreen,
                    // Data dummy sparkline - akan diganti dengan data historis Fase 2
                    sparklineData: const [4.0, 6.5, 5.0, 7.5, 8.0, 7.0, 8.2],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _EnergyMetricItem(
                    label: AppStrings.energyVoltage,
                    value: data.voltage.toStringAsFixed(1),
                    unit: AppStrings.energyUnitVolt,
                    sparklineColor: AppColors.chartRed,
                    sparklineData: const [20.0, 22.0, 21.5, 23.0, 24.0, 23.5, 24.6],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _EnergyMetricItem(
                    label: AppStrings.energyPower,
                    value: data.power.toInt().toString(),
                    unit: AppStrings.energyUnitWatt,
                    sparklineColor: AppColors.chartYellow,
                    sparklineData: const [120.0, 150.0, 140.0, 170.0, 180.0, 195.0, 206.0],
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
// WIDGET METRIK ENERGI INDIVIDUAL
// ---------------------------------------------------------------------------

class _EnergyMetricItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color sparklineColor;
  final List<double> sparklineData;

  const _EnergyMetricItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.sparklineColor,
    required this.sparklineData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
              fontFamily: AppAssets.fontFamily,
            ),
          ),
          const SizedBox(height: 4),

          // Nilai besar
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: AppAssets.fontFamily,
              height: 1.1,
            ),
          ),

          // Unit kecil
          Text(
            unit,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontFamily: AppAssets.fontFamily,
            ),
          ),
          const SizedBox(height: 8),

          // Mini Sparkline
          SizedBox(
            height: 28,
            child: CustomPaint(
              painter: _SparklinePainter(
                data: sparklineData,
                color: sparklineColor,
              ),
              size: const Size(double.infinity, 28),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CUSTOM PAINTER UNTUK MINI SPARKLINE
// Menggambar garis tren sederhana dengan CustomPaint.
// Tidak memerlukan library tambahan.
// ---------------------------------------------------------------------------

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  const _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final minVal = data.reduce(math.min);
    final maxVal = data.reduce(math.max);
    final range = maxVal - minVal;

    // Paint untuk garis
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();

    for (int i = 0; i < data.length; i++) {
      final x = size.width * (i / (data.length - 1));
      final normalizedY = range == 0 ? 0.5 : (data[i] - minVal) / range;
      // Balik Y karena koordinat canvas dimulai dari atas
      final y = size.height * (1 - normalizedY);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}

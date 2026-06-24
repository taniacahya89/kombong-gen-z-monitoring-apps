// lib/presentation/widgets/dashboard/water_tank_card.dart
//
// Widget kartu Water Tank untuk halaman Dashboard.
//
// Visualisasi menggunakan CustomPainter dengan efek:
//   - Tangki berbentuk rounded rectangle dengan tepi "kaca"
//   - Air bergelombang (sine wave) yang naik-turun sesuai level sensor
//   - Warna air berubah dinamis: biru (penuh) -> kuning -> merah (kosong)
//   - Animasi gelombang berjalan terus-menerus
//   - Gelembung kecil sebagai aksen estetis
//   - Nilai cm + status pill di samping tangki

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/water_tank_model.dart';
import '../../../core/utils/app_utils.dart';

class WaterTankCard extends StatelessWidget {
  final WaterTankModel data;

  const WaterTankCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final levelPercentage = data.levelPercentage;
    final statusText = AppUtils.getWaterTankStatus(levelPercentage);
    final statusColor = AppUtils.getWaterTankStatusColor(levelPercentage);

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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.water_drop,
                  color: Color(0xFF1565C0),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                AppStrings.waterTankTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // Badge persentase kecil di kanan atas
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${(levelPercentage * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Konten utama: Tangki + Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Visualisasi tangki air dengan animasi
              _AnimatedWaterTank(
                levelPercentage: levelPercentage,
                statusColor: statusColor,
              ),
              const SizedBox(width: 20),

              // Info sebelah kanan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nilai cm besar
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: data.currentHeightCm.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.0,
                            ),
                          ),
                          const TextSpan(
                            text: ' cm',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    Text(
                      'dari ${data.maxCapacityCm.toInt()} cm kapasitas',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Progress bar mini horizontal
                    _LevelProgressBar(
                      levelPercentage: levelPercentage,
                      statusColor: statusColor,
                    ),
                    const SizedBox(height: 14),

                    // Pill status
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(26),
                        border: Border.all(color: statusColor, width: 1.2),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            levelPercentage >= 0.7
                                ? Icons.check_circle_outline
                                : levelPercentage >= 0.4
                                    ? Icons.warning_amber_outlined
                                    : Icons.error_outline,
                            size: 13,
                            color: statusColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ANIMATED WATER TANK
// Menggunakan AnimationController untuk wave effect yang smooth.
// ---------------------------------------------------------------------------

class _AnimatedWaterTank extends StatefulWidget {
  final double levelPercentage;
  final Color statusColor;

  const _AnimatedWaterTank({
    required this.levelPercentage,
    required this.statusColor,
  });

  @override
  State<_AnimatedWaterTank> createState() => _AnimatedWaterTankState();
}

class _AnimatedWaterTankState extends State<_AnimatedWaterTank>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // gelombang berjalan terus-menerus
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  // Warna air berdasarkan level
  Color get _waterColor {
    if (widget.levelPercentage >= 0.6) return const Color(0xFF29B6F6); // biru segar
    if (widget.levelPercentage >= 0.35) return const Color(0xFFFFA726); // oranye
    return const Color(0xFFEF5350); // merah
  }

  Color get _waterColorLight {
    if (widget.levelPercentage >= 0.6) return const Color(0xFF4FC3F7);
    if (widget.levelPercentage >= 0.35) return const Color(0xFFFFB74D);
    return const Color(0xFFEF9A9A);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(72, 148),
          painter: _WaterTankPainter(
            levelPercentage: widget.levelPercentage,
            wavePhase: _waveController.value * 2 * math.pi,
            waterColor: _waterColor,
            waterColorLight: _waterColorLight,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// CUSTOM PAINTER - WATER TANK
// Menggambar:
//   1. Badan tangki (outline rounded rectangle dengan efek kaca)
//   2. Air dengan gelombang sine yang beranimasi
//   3. Refleksi / highlight kaca di tepi kiri
//   4. Gelembung kecil acak
// ---------------------------------------------------------------------------

class _WaterTankPainter extends CustomPainter {
  final double levelPercentage;
  final double wavePhase;
  final Color waterColor;
  final Color waterColorLight;

  static const double _cornerRadius = 20.0;
  static const double _borderWidth = 2.5;
  static const double _waveAmplitude = 5.0;
  static const double _waveFrequency = 1.5;

  const _WaterTankPainter({
    required this.levelPercentage,
    required this.wavePhase,
    required this.waterColor,
    required this.waterColorLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tankRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(_cornerRadius),
    );

    // -- Clip semua drawing ke bentuk tangki --
    canvas.save();
    canvas.clipRRect(tankRect);

    // 1. Background tangki (abu sangat muda)
    canvas.drawRRect(
      tankRect,
      Paint()..color = const Color(0xFFF5F7FA),
    );

    // 2. Gambar air bergelombang
    _drawWater(canvas, size);

    // 3. Overlay gradien kaca di atas air (refleksi)
    _drawGlassOverlay(canvas, size);

    // 4. Gelembung kecil
    _drawBubbles(canvas, size);

    canvas.restore();

    // 5. Border tangki (di luar clip agar terlihat bersih)
    canvas.drawRRect(
      tankRect,
      Paint()
        ..color = const Color(0xFFCFD8DC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _borderWidth,
    );

    // 6. Garis skala level (di luar clip, di sisi kanan tangki)
    _drawLevelScale(canvas, size);
  }

  void _drawWater(Canvas canvas, Size size) {
    if (levelPercentage <= 0) return;

    // Tinggi air dari bawah
    final waterHeight = size.height * levelPercentage;
    final waterTop = size.height - waterHeight;

    final path = Path();

    // Buat garis gelombang sine dari kiri ke kanan
    path.moveTo(0, waterTop);

    for (double x = 0; x <= size.width; x++) {
      final y = waterTop +
          _waveAmplitude *
              math.sin((x / size.width * _waveFrequency * 2 * math.pi) +
                  wavePhase);
      path.lineTo(x, y);
    }

    // Tutup ke bawah kiri
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Gradient air: lebih terang di atas, lebih gelap di bawah
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        waterColorLight,
        waterColor,
        waterColor.withAlpha(230),
      ],
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(0, waterTop, size.width, waterHeight),
        ),
    );

    // Gelombang kedua (offset phase) untuk kedalaman
    final path2 = Path();
    path2.moveTo(0, waterTop + 3);

    for (double x = 0; x <= size.width; x++) {
      final y = waterTop +
          3 +
          (_waveAmplitude * 0.6) *
              math.sin((x / size.width * _waveFrequency * 2 * math.pi) +
                  wavePhase +
                  math.pi * 0.7);
      path2.lineTo(x, y);
    }

    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    canvas.drawPath(
      path2,
      Paint()..color = waterColor.withAlpha(120),
    );
  }

  void _drawGlassOverlay(Canvas canvas, Size size) {
    // Highlight vertikal di sisi kiri tangki (efek kaca)
    final highlightRect = Rect.fromLTWH(6, 8, 10, size.height * 0.6);
    final highlightGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withAlpha(100),
        Colors.white.withAlpha(10),
      ],
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(5)),
      Paint()
        ..shader = highlightGradient.createShader(highlightRect)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawBubbles(Canvas canvas, Size size) {
    if (levelPercentage <= 0.05) return;

    // Gelembung statis (posisi berdasarkan level, bukan animasi)
    // Ini sengaja dibuat sederhana agar tidak membebani render
    final bubblePaint = Paint()
      ..color = Colors.white.withAlpha(140)
      ..style = PaintingStyle.fill;

    final waterTop = size.height * (1 - levelPercentage);

    // Gelembung kecil di dalam air (posisi relatif terhadap permukaan air)
    final bubbles = [
      Offset(size.width * 0.3, waterTop + (size.height - waterTop) * 0.4),
      Offset(size.width * 0.65, waterTop + (size.height - waterTop) * 0.65),
      Offset(size.width * 0.45, waterTop + (size.height - waterTop) * 0.8),
    ];

    for (final b in bubbles) {
      canvas.drawCircle(b, 3, bubblePaint);
      canvas.drawCircle(b, 3,
          Paint()
            ..color = Colors.white.withAlpha(80)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }
  }

  void _drawLevelScale(Canvas canvas, Size size) {
    // Garis skala di sisi kanan luar tangki (4 level: 25%, 50%, 75%, 100%)
    final scalePaint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 1;

    const textStyle = TextStyle(
      color: Color(0xFF90A4AE),
      fontSize: 8,
      fontWeight: FontWeight.w500,
    );

    for (int i = 1; i <= 4; i++) {
      final yPos = size.height - (size.height * (i / 4));
      canvas.drawLine(
        Offset(size.width + 4, yPos),
        Offset(size.width + 10, yPos),
        scalePaint,
      );

      // Label
      final tp = TextPainter(
        text: TextSpan(text: '${i * 25}', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width + 12, yPos - 5));
    }
  }

  @override
  bool shouldRepaint(_WaterTankPainter oldDelegate) {
    return oldDelegate.levelPercentage != levelPercentage ||
        oldDelegate.wavePhase != wavePhase;
  }
}

// ---------------------------------------------------------------------------
// PROGRESS BAR LEVEL HORIZONTAL
// Bar tipis yang menunjukkan persentase level secara linear.
// ---------------------------------------------------------------------------

class _LevelProgressBar extends StatelessWidget {
  final double levelPercentage;
  final Color statusColor;

  const _LevelProgressBar({
    required this.levelPercentage,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Level Air',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(levelPercentage * 100).toInt()}%',
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Stack(
            children: [
              // Background track
              Container(
                height: 8,
                color: const Color(0xFFECEFF1),
              ),
              // Fill
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                widthFactor: levelPercentage,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withAlpha(180),
                        statusColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

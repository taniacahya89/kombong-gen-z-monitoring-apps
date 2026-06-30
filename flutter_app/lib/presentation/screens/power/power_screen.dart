// lib/presentation/screens/power/power_screen.dart
//
// Halaman Daya - Monitoring tegangan dan arus kandang.
//
// Desain (dari gambar referensi):
//   - Header: judul "Tegangan dan Arus" + subtitle
//   - Kartu utama "GENERATING POWER": nilai power besar + sparkline kuning
//   - Dua kartu kecil: CURRENT (A) sparkline hijau + VOLTAGE (V) sparkline merah
//   - Kartu grafik garis historis (fl_chart) dengan tiga series: Power, Current, Voltage
//   - Bottom Navigation Bar: sama dengan Dashboard (item Daya aktif)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/providers/power_provider.dart';
import '../../../data/models/solar_metrics_model.dart';

class PowerScreen extends ConsumerStatefulWidget {
  const PowerScreen({super.key});

  @override
  ConsumerState<PowerScreen> createState() => _PowerScreenState();
}

class _PowerScreenState extends ConsumerState<PowerScreen> {

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final latestAsync = ref.watch(powerLatestProvider);
    final historyAsync = ref.watch(powerHistoryProvider);

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
                        AppStrings.powerPageTitle,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: AppAssets.fontFamily,
                        ),
                      ),
                      Text(
                        AppStrings.powerPageSubtitle,
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
                    onPressed: () {
                      ref.invalidate(powerLatestProvider);
                      ref.invalidate(powerHistoryProvider);
                    },
                  ),
                ],
              ),
            ),

            // Konten scrollable
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(powerLatestProvider);
                  ref.invalidate(powerHistoryProvider);
                },
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: latestAsync.when(
                    loading: () => _buildLoadingState(),
                    error: (e, _) => _buildErrorState(e.toString(), ref),
                    data: (latest) => _buildContent(context, latest, historyAsync),
                  ),
                ),
              ),
            ),

            // Bottom Nav
            _buildBottomNavBar(context, 2),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SolarMetricsModel latest,
    AsyncValue<List<SolarMetricsModel>> historyAsync,
  ) {
    return Column(
      children: [
        // Kartu Generating Power (Power besar)
        _buildGeneratingPowerCard(latest.power),
        const SizedBox(height: 16),

        // Dua kartu kecil: Current dan Voltage
        Row(
          children: [
            Expanded(
              child: _buildSmallMetricCard(
                label: AppStrings.powerCurrent,
                value: latest.current,
                unit: AppStrings.energyUnitAmpere,
                color: AppColors.chartGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallMetricCard(
                label: AppStrings.powerVoltage,
                value: latest.voltage,
                unit: AppStrings.energyUnitVolt,
                color: AppColors.chartRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Kartu grafik historis
        historyAsync.when(
          loading: () => _buildChartLoading(),
          error: (e, _) => _buildChartError(e.toString()),
          data: (history) => _buildHistoryChart(history, latest),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // KARTU GENERATING POWER
  // ---------------------------------------------------------------------------

  Widget _buildGeneratingPowerCard(double power) {
    return Container(
      width: double.infinity,
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
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GENERATING POWER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                  fontFamily: AppAssets.fontFamily,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: power.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: AppAssets.fontFamily,
                      ),
                    ),
                    const TextSpan(
                      text: ' W',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        fontFamily: AppAssets.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          // Sparkline dekoratif kuning
          const SizedBox(
            width: 80,
            height: 48,
            child: CustomPaint(painter: _SparklinePainter(AppColors.chartYellow)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KARTU METRIK KECIL (Current / Voltage)
  // ---------------------------------------------------------------------------

  Widget _buildSmallMetricCard({
    required String label,
    required double value,
    required String unit,
    required Color color,
  }) {
    return Container(
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
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
              fontFamily: AppAssets.fontFamily,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: AppAssets.fontFamily,
                  ),
                ),
                TextSpan(
                  text: '\n$unit',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: AppAssets.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: CustomPaint(painter: _SparklinePainter(color)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GRAFIK HISTORIS
  // ---------------------------------------------------------------------------

  Widget _buildHistoryChart(
    List<SolarMetricsModel> history,
    SolarMetricsModel latest,
  ) {
    if (history.isEmpty) {
      return _buildChartEmpty();
    }

    List<FlSpot> powerSpots = [];
    List<FlSpot> currentSpots = [];
    List<FlSpot> voltageSpots = [];

    for (int i = 0; i < history.length; i++) {
      powerSpots.add(FlSpot(i.toDouble(), history[i].power));
      currentSpots.add(FlSpot(i.toDouble(), history[i].current));
      voltageSpots.add(FlSpot(i.toDouble(), history[i].voltage));
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Poultry House 1 - Electrical Monitoring',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: AppAssets.fontFamily,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildLegend('Power (W)', AppColors.chartYellow),
              const SizedBox(width: 12),
              _buildLegend('Current (A)', AppColors.chartGreen),
              const SizedBox(width: 12),
              _buildLegend('Voltage (V)', AppColors.chartRed),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                backgroundColor: AppColors.surface,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: AppColors.divider,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                          fontFamily: AppAssets.fontFamily,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (history.length / 4).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= history.length) {
                          return const SizedBox.shrink();
                        }
                        final recordedAt = history[idx].recordedAt;
                        if (recordedAt == null) return const SizedBox.shrink();
                        return Text(
                          DateFormat('HH:mm').format(recordedAt.toLocal()),
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                            fontFamily: AppAssets.fontFamily,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _buildLineBarData(powerSpots, AppColors.chartYellow),
                  _buildLineBarData(currentSpots, AppColors.chartGreen),
                  _buildLineBarData(voltageSpots, AppColors.chartRed),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildValueLabel('Power: ${latest.power.toStringAsFixed(0)} W'),
              _buildValueLabel('Current: ${latest.current.toStringAsFixed(1)} A'),
              _buildValueLabel('Voltage: ${latest.voltage.toStringAsFixed(1)} V'),
            ],
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLineBarData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontFamily: AppAssets.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildValueLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.inputBorder),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textPrimary,
          fontFamily: AppAssets.fontFamily,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildErrorState(String error, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_outlined, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat data kelistrikan',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                ref.invalidate(powerLatestProvider);
                ref.invalidate(powerHistoryProvider);
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLoading() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildChartError(String error) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Center(
        child: Text(
          'Grafik historis tidak tersedia',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontFamily: AppAssets.fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _buildChartEmpty() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart_rounded, color: AppColors.textHint, size: 32),
            SizedBox(height: 8),
            Text(
              'Belum ada data historis',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: AppAssets.fontFamily,
              ),
            ),
          ],
        ),
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

// ---------------------------------------------------------------------------
// CUSTOM PAINTER: Sparkline dekoratif
// ---------------------------------------------------------------------------

class _SparklinePainter extends CustomPainter {
  final Color color;
  const _SparklinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.15, size.height * 0.6),
      Offset(size.width * 0.3, size.height * 0.7),
      Offset(size.width * 0.45, size.height * 0.4),
      Offset(size.width * 0.6, size.height * 0.5),
      Offset(size.width * 0.75, size.height * 0.2),
      Offset(size.width, size.height * 0.1),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

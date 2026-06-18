// lib/core/utils/app_utils.dart
//
// Kumpulan fungsi utilitas global yang digunakan di seluruh aplikasi.

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class AppUtils {
  AppUtils._();

  // -------------------------------------------------------------------------
  // FORMAT WAKTU
  // -------------------------------------------------------------------------

  /// Memformat jam menjadi string dua digit. Contoh: 8 -> "08"
  static String formatHour(int hour) => hour.toString().padLeft(2, '0');

  /// Memformat waktu dari string "HH:MM" menjadi format tampilan "HH.MM".
  static String formatScheduleTime(String time) => time.replaceAll(':', '.');

  // -------------------------------------------------------------------------
  // KALKULASI LEVEL TANGKI AIR
  // -------------------------------------------------------------------------

  /// Menghitung persentase ketinggian air (0.0 - 1.0).
  static double calculateWaterLevel(double currentCm, double maxCm) {
    if (maxCm <= 0) return 0.0;
    return (currentCm / maxCm).clamp(0.0, 1.0);
  }

  /// Menentukan teks status tangki air berdasarkan persentase level.
  static String getWaterTankStatus(double levelPercentage) {
    if (levelPercentage >= 0.7) return AppStrings.waterTankStatusSafe;
    if (levelPercentage >= 0.4) return AppStrings.waterTankStatusWarning;
    return AppStrings.waterTankStatusLow;
  }

  /// Menentukan warna status tangki air berdasarkan persentase level.
  static Color getWaterTankStatusColor(double levelPercentage) {
    if (levelPercentage >= 0.7) return AppColors.primary;
    if (levelPercentage >= 0.4) return AppColors.tankLevelYellow;
    return AppColors.tankLevelRed;
  }

  // -------------------------------------------------------------------------
  // FORMAT ANGKA SENSOR
  // -------------------------------------------------------------------------

  /// Memformat nilai sensor dengan satu desimal. Contoh: 12.456 -> "12.5"
  static String formatSensorValue(double value) => value.toStringAsFixed(1);

  /// Memformat nilai daya tanpa desimal. Contoh: 206.0 -> "206"
  static String formatPowerValue(double value) => value.toInt().toString();

  // -------------------------------------------------------------------------
  // SNACKBAR HELPER
  // -------------------------------------------------------------------------

  static void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textOnPrimary),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textOnPrimary),
        ),
        backgroundColor: AppColors.textAccentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // VALIDASI FORM
  // -------------------------------------------------------------------------

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.errorEmailEmpty;
    }
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return AppStrings.errorEmailInvalid;
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.errorPasswordEmpty;
    if (value.length < 8) return AppStrings.errorPasswordShort;
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.errorNameEmpty;
    return null;
  }
}

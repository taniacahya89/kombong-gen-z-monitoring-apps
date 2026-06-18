// lib/data/models/water_tank_model.dart
//
// Model data untuk sensor tangki air.
// Dibuat sesuai kontrak JSON payload:
// { "water_tank": { "current_height_cm": 45, "max_capacity_cm": 55, "status": "Aman" } }

class WaterTankModel {
  final double currentHeightCm;
  final double maxCapacityCm;
  final String status;

  const WaterTankModel({
    required this.currentHeightCm,
    required this.maxCapacityCm,
    required this.status,
  });

  // Hitung persentase level secara langsung dari model
  double get levelPercentage {
    if (maxCapacityCm <= 0) return 0.0;
    return (currentHeightCm / maxCapacityCm).clamp(0.0, 1.0);
  }

  // Data dummy untuk digunakan selama backend belum tersedia
  factory WaterTankModel.dummy() {
    return const WaterTankModel(
      currentHeightCm: 55,
      maxCapacityCm: 55,
      status: 'Aman',
    );
  }

  factory WaterTankModel.fromJson(Map<String, dynamic> json) {
    // Backend /sensors/water-tank mengembalikan data flat (tanpa wrapper).
    // Format MQTT payload menggunakan wrapper 'water_tank'.
    // Tangani keduanya.
    final data = json.containsKey('water_tank')
        ? json['water_tank'] as Map<String, dynamic>
        : json;

    return WaterTankModel(
      currentHeightCm: (data['current_height_cm'] as num).toDouble(),
      maxCapacityCm: (data['max_capacity_cm'] as num).toDouble(),
      status: data['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'water_tank': {
        'current_height_cm': currentHeightCm,
        'max_capacity_cm': maxCapacityCm,
        'status': status,
      },
    };
  }

  WaterTankModel copyWith({
    double? currentHeightCm,
    double? maxCapacityCm,
    String? status,
  }) {
    return WaterTankModel(
      currentHeightCm: currentHeightCm ?? this.currentHeightCm,
      maxCapacityCm: maxCapacityCm ?? this.maxCapacityCm,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'WaterTankModel(currentHeightCm: $currentHeightCm, maxCapacityCm: $maxCapacityCm, status: $status)';
  }
}

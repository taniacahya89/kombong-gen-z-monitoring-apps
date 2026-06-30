// lib/data/models/solar_metrics_model.dart
//
// Model data untuk sensor kelistrikan (panel surya / daya kandang).
//
// Kontrak JSON dari backend (endpoint /sensors/power):
// {
//   "id": 42,
//   "voltage": 24.6,
//   "current": 8.2,
//   "power": 206.0,
//   "recorded_at": "2025-06-17T10:00:00Z"
// }
//
// Kontrak JSON dari endpoint /sensors/power/history:
// Response berisi list SolarMetricsModel dengan field yang sama.

class SolarMetricsModel {
  final int? id;
  final double voltage;
  final double current;
  final double power;
  final DateTime? recordedAt;

  const SolarMetricsModel({
    this.id,
    required this.voltage,
    required this.current,
    required this.power,
    this.recordedAt,
  });

  factory SolarMetricsModel.fromRealtimeDb(Map<String, dynamic> data) {
    return SolarMetricsModel(
      voltage: (data['voltage'] as num).toDouble(),
      current: (data['current'] as num).toDouble(),
      power: (data['power'] as num).toDouble(),
      recordedAt: data['recorded_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['recorded_at'] as int)
          : null,
    );
  }

  factory SolarMetricsModel.fromJson(Map<String, dynamic> json) {
    // Mendukung dua format response:
    // 1. Format langsung dari database (key flat: voltage, current, power)
    // 2. Format lama dengan wrapper solar_metrics (untuk backward compatibility)
    if (json.containsKey('solar_metrics')) {
      final metrics = json['solar_metrics'] as Map<String, dynamic>;
      return SolarMetricsModel(
        voltage: (metrics['voltage'] as num).toDouble(),
        current: (metrics['current'] as num).toDouble(),
        power: (metrics['power'] as num).toDouble(),
      );
    }

    return SolarMetricsModel(
      id: json['id'] as int?,
      voltage: (json['voltage'] as num).toDouble(),
      current: (json['current'] as num).toDouble(),
      power: (json['power'] as num).toDouble(),
      recordedAt: json['recorded_at'] != null
          ? DateTime.tryParse(json['recorded_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'voltage': voltage,
      'current': current,
      'power': power,
      'recorded_at': recordedAt?.toIso8601String(),
    };
  }

  SolarMetricsModel copyWith({
    int? id,
    double? voltage,
    double? current,
    double? power,
    DateTime? recordedAt,
  }) {
    return SolarMetricsModel(
      id: id ?? this.id,
      voltage: voltage ?? this.voltage,
      current: current ?? this.current,
      power: power ?? this.power,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  String toString() {
    return 'SolarMetricsModel(voltage: $voltage V, current: $current A, power: $power W)';
  }
}

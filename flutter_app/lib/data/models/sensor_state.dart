// lib/data/models/sensor_state.dart
//
// Model data tunggal untuk state sensor IoT (ESP32).
// Menyimpan data realtime dan menyediakan nilai komputasi daya (power).

class SensorState {
  final double distance;
  final double voltage;
  final double currentMilliAmpere;
  final DateTime lastUpdated;

  const SensorState({
    required this.distance,
    required this.voltage,
    required this.currentMilliAmpere,
    required this.lastUpdated,
  });

  /// State awal default ketika aplikasi baru dimulai dan belum menerima data sensor.
  factory SensorState.initial() {
    return SensorState(
      distance: 0.0,
      voltage: 0.0,
      currentMilliAmpere: 0.0,
      lastUpdated: DateTime.now(),
    );
  }

  /// Nilai arus dalam Ampere.
  /// Catatan: meskipun field bernama currentMilliAmpere (legacy naming),
  /// ESP32 sudah mengirim nilai dalam satuan Ampere (misal: 0.5 A),
  /// sehingga TIDAK perlu dibagi 1000.
  double get currentAmpere => currentMilliAmpere;

  /// Hitung nilai daya (Watt) secara dinamis dari tegangan (V) × arus (A).
  double get power => voltage * currentAmpere;

  SensorState copyWith({
    double? distance,
    double? voltage,
    double? currentMilliAmpere,
    DateTime? lastUpdated,
  }) {
    return SensorState(
      distance: distance ?? this.distance,
      voltage: voltage ?? this.voltage,
      currentMilliAmpere: currentMilliAmpere ?? this.currentMilliAmpere,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'SensorState(distance: $distance cm, voltage: $voltage V, current: ${currentAmpere.toStringAsFixed(3)} A, power: ${power.toStringAsFixed(2)} W, updated: $lastUpdated)';
  }
}

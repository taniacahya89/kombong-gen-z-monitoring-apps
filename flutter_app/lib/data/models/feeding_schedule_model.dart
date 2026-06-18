// lib/data/models/feeding_schedule_model.dart
//
// Model data untuk jadwal pakan ternak.
//
// Kontrak JSON dari backend:
// {
//   "id": 1,
//   "label": "Pakan Pagi",
//   "time": "07:00",
//   "feed_type": "pakan",
//   "is_active": true,
//   "created_at": "2025-06-17T00:00:00Z",
//   "updated_at": "2025-06-17T00:00:00Z"
// }
//
// Field `feed_type` membedakan kategori:
//   - "pakan": jadwal pemberian pakan ayam
//   - "minum": jadwal pemberian minum ayam

class FeedingScheduleModel {
  final int id;
  final String label;
  final String time;
  final String feedType; // "pakan" atau "minum"
  final bool isActive;

  const FeedingScheduleModel({
    required this.id,
    required this.label,
    required this.time,
    required this.feedType,
    required this.isActive,
  });

  // Mengembalikan true jika ini adalah jadwal pakan (bukan minum).
  bool get isPakan => feedType == 'pakan';

  factory FeedingScheduleModel.fromJson(Map<String, dynamic> json) {
    return FeedingScheduleModel(
      id: json['id'] as int,
      label: json['label'] as String? ?? 'Jadwal Pakan',
      time: json['time'] as String,
      feedType: json['feed_type'] as String? ?? 'pakan',
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'time': time,
      'feed_type': feedType,
      'is_active': isActive,
    };
  }

  // Payload untuk endpoint POST (buat jadwal baru)
  Map<String, dynamic> toCreatePayload() {
    return {
      'label': label,
      'time': time,
      'feed_type': feedType,
      'is_active': isActive,
    };
  }

  // Payload untuk endpoint PUT (update jadwal)
  Map<String, dynamic> toUpdatePayload() {
    return {
      'label': label,
      'time': time,
      'feed_type': feedType,
      'is_active': isActive,
    };
  }

  FeedingScheduleModel copyWith({
    int? id,
    String? label,
    String? time,
    String? feedType,
    bool? isActive,
  }) {
    return FeedingScheduleModel(
      id: id ?? this.id,
      label: label ?? this.label,
      time: time ?? this.time,
      feedType: feedType ?? this.feedType,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'FeedingScheduleModel(id: $id, label: $label, time: $time, feedType: $feedType, isActive: $isActive)';
  }
}

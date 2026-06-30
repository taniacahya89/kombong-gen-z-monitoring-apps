// lib/data/models/feeding_schedule_model.dart
//
// Model jadwal pakan, kompatibel dengan Cloud Firestore.
// Menggunakan firestoreId (String) sebagai identifier utama, bukan int.

import 'package:cloud_firestore/cloud_firestore.dart';

class FeedingScheduleModel {
  final String firestoreId; // Firestore document ID
  final String label;
  final String time;        // format "HH:MM"
  final String feedType;    // "pakan" atau "minum"
  final bool isActive;

  const FeedingScheduleModel({
    this.firestoreId = '',
    required this.label,
    required this.time,
    required this.feedType,
    required this.isActive,
    dynamic id, // parameter warisan (legacy) untuk kompatibilitas UI
  });

  // Untuk kompatibilitas dengan kode UI yang masih pakai int id
  // (akan dihapus setelah refactor screen selesai)
  int get id => firestoreId.hashCode;

  bool get isPakan => feedType == 'pakan';

  factory FeedingScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedingScheduleModel(
      firestoreId: doc.id,
      label: data['label'] as String? ?? 'Jadwal Pakan',
      time: data['time'] as String? ?? '07:00',
      feedType: data['feed_type'] as String? ?? 'pakan',
      isActive: data['is_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'label': label,
      'time': time,
      'feed_type': feedType,
      'is_active': isActive,
    };
  }

  // Alias untuk backward compatibility dengan provider
  Map<String, dynamic> toCreatePayload() => toFirestore();
  Map<String, dynamic> toUpdatePayload() => toFirestore();

  FeedingScheduleModel copyWith({
    String? firestoreId,
    String? label,
    String? time,
    String? feedType,
    bool? isActive,
  }) {
    return FeedingScheduleModel(
      firestoreId: firestoreId ?? this.firestoreId,
      label: label ?? this.label,
      time: time ?? this.time,
      feedType: feedType ?? this.feedType,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() =>
      'FeedingScheduleModel(id: $firestoreId, label: $label, time: $time, feedType: $feedType, isActive: $isActive)';
}

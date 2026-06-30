// lib/data/models/notification_model.dart
//
// Model notifikasi sistem, kompatibel dengan Cloud Firestore.
// Menggunakan firestoreId (String) sebagai identifier utama.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/routes/app_routes.dart';

class NotificationModel {
  final String firestoreId; // Firestore document ID
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.firestoreId,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  // Untuk backward compatibility dengan UI yang masih pakai int id
  int get id => firestoreId.hashCode;

  String? get destinationRoute {
    final t = title.toLowerCase();
    if (t.contains('air') || t.contains('tangki') || t.contains('level')) {
      return AppRoutePaths.dashboard;
    }
    if (t.contains('tegangan') || t.contains('panel') || t.contains('daya') ||
        t.contains('listrik') || t.contains('surya')) {
      return AppRoutePaths.power;
    }
    return null;
  }

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAtRaw = data['created_at'];
    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else {
      createdAt = DateTime.now();
    }
    return NotificationModel(
      firestoreId: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      isRead: data['is_read'] as bool? ?? false,
      createdAt: createdAt,
    );
  }

  NotificationModel copyWith({
    String? firestoreId,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      firestoreId: firestoreId ?? this.firestoreId,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'NotificationModel(id: $firestoreId, title: $title, isRead: $isRead)';
}

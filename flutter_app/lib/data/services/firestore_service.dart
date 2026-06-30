// lib/data/services/firestore_service.dart
//
// Service untuk Jadwal Pakan dan Notifikasi via Cloud Firestore.
// Menggantikan REST API endpoint /feeding/schedules dan /notifications.

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/feeding_schedule_model.dart';
import '../models/notification_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  // ---------------------------------------------------------------------------
  // SINKRONISASI JADWAL KE REALTIME DATABASE (UNTUK ESP32)
  // ---------------------------------------------------------------------------
  Future<void> _syncSchedulesToRealtimeDb() async {
    try {
      final list = await getFeedingSchedules();
      final activeSchedules = list
          .where((s) => s.isActive && s.feedType == 'pakan')
          .map((s) => s.time)
          .toList();
      
      // Tulis array jadwal (format string "HH:mm") ke path kontrol/jam_pakan di RTDB
      await _rtdb.ref('kontrol/jam_pakan').set(activeSchedules);
      debugPrint('[FirestoreSync] Jadwal pakan disinkronkan ke RTDB: $activeSchedules');
    } catch (e) {
      debugPrint('[FirestoreSync] Gagal sinkronisasi jadwal ke RTDB: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // JADWAL PAKAN
  // ---------------------------------------------------------------------------

  /// Stream real-time daftar jadwal pakan dari Firestore.
  Stream<List<FeedingScheduleModel>> watchFeedingSchedules() {
    return _db
        .collection('feeding_schedules')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => FeedingScheduleModel.fromFirestore(doc))
              .toList();
          // Urutkan di memori (Dart) untuk menghindari keharusan membuat composite index di Firestore
          list.sort((a, b) {
            final typeComp = a.feedType.compareTo(b.feedType);
            if (typeComp != 0) return typeComp;
            return a.time.compareTo(b.time);
          });
          return list;
        });
  }

  /// Baca daftar jadwal sekali (untuk non-stream).
  Future<List<FeedingScheduleModel>> getFeedingSchedules() async {
    final snap = await _db
        .collection('feeding_schedules')
        .get();
    final list = snap.docs.map((doc) => FeedingScheduleModel.fromFirestore(doc)).toList();
    list.sort((a, b) {
      final typeComp = a.feedType.compareTo(b.feedType);
      if (typeComp != 0) return typeComp;
      return a.time.compareTo(b.time);
    });
    return list;
  }

  /// Buat jadwal pakan baru.
  Future<FeedingScheduleModel> createFeedingSchedule(FeedingScheduleModel schedule) async {
    final docRef = await _db.collection('feeding_schedules').add({
      'label': schedule.label,
      'time': schedule.time,
      'feed_type': schedule.feedType,
      'is_active': schedule.isActive,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    final doc = await docRef.get();
    final model = FeedingScheduleModel.fromFirestore(doc);
    await _syncSchedulesToRealtimeDb();
    return model;
  }

  /// Update jadwal pakan yang sudah ada.
  Future<FeedingScheduleModel> updateFeedingSchedule(FeedingScheduleModel schedule) async {
    await _db.collection('feeding_schedules').doc(schedule.firestoreId).update({
      'label': schedule.label,
      'time': schedule.time,
      'feed_type': schedule.feedType,
      'is_active': schedule.isActive,
      'updated_at': FieldValue.serverTimestamp(),
    });
    final doc = await _db.collection('feeding_schedules').doc(schedule.firestoreId).get();
    final model = FeedingScheduleModel.fromFirestore(doc);
    await _syncSchedulesToRealtimeDb();
    return model;
  }

  /// Hapus jadwal pakan berdasarkan Firestore document ID.
  Future<void> deleteFeedingSchedule(String firestoreId) async {
    await _db.collection('feeding_schedules').doc(firestoreId).delete();
    await _syncSchedulesToRealtimeDb();
  }

  // ---------------------------------------------------------------------------
  // NOTIFIKASI
  // ---------------------------------------------------------------------------

  /// Stream notifikasi real-time.
  Stream<List<NotificationModel>> watchNotifications({int limit = 50}) {
    return _db
        .collection('notifications')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList());
  }

  /// Tandai satu notifikasi sebagai sudah dibaca.
  Future<void> markNotificationRead(String firestoreId) async {
    await _db.collection('notifications').doc(firestoreId).update({'is_read': true});
  }

  /// Tandai semua notifikasi sebagai sudah dibaca (batch write).
  Future<void> markAllNotificationsRead() async {
    final snap = await _db
        .collection('notifications')
        .where('is_read', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }

  /// Buat notifikasi baru.
  Future<void> createNotification({
    required String title,
    required String body,
    DateTime? createdAt,
  }) async {
    await _db.collection('notifications').add({
      'title': title,
      'body': body,
      'is_read': false,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt)
          : FieldValue.serverTimestamp(),
    });
  }
}

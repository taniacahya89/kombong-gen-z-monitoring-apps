// lib/data/models/notification_model.dart
//
// Model data untuk notifikasi sistem.
//
// Kontrak JSON dari backend:
// {
//   "id": 1,
//   "title": "Peringatan Level Air",
//   "body": "Level air tangki telah mencapai batas rendah (< 20%).",
//   "is_read": false,
//   "created_at": "2025-06-17T10:00:00Z"
// }
//
// Routing notifikasi:
//   Field `destinationRoute` adalah computed getter yang menentukan ke halaman
//   mana user diarahkan saat menekan item notifikasi. Logika ini berbasis
//   string matching pada `title` — tidak memerlukan perubahan schema database.
//
//   Pemetaan:
//     - Notifikasi air/tangki  -> /dashboard
//     - Notifikasi tegangan/panel surya -> /power
//     - Notifikasi lainnya     -> null (tidak ada navigasi)

import '../../core/routes/app_routes.dart';

class NotificationModel {
  final int id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  /// Menentukan halaman tujuan navigasi berdasarkan konten judul notifikasi.
  ///
  /// Backend menulis title dengan kata kunci spesifik (contoh: "Level Air Rendah",
  /// "Tegangan Panel Surya Tinggi"). Getter ini melakukan matching case-insensitive
  /// terhadap kata kunci tersebut untuk menentukan rute yang relevan.
  ///
  /// Mengembalikan null jika tidak ada halaman yang cocok, sehingga caller
  /// dapat memilih untuk menampilkan dialog detail saja tanpa navigasi.
  String? get destinationRoute {
    final t = title.toLowerCase();
    // Notifikasi terkait tangki air -> halaman Dashboard
    if (t.contains('air') || t.contains('tangki') || t.contains('level')) {
      return AppRoutePaths.dashboard;
    }
    // Notifikasi terkait panel surya / kelistrikan -> halaman Daya
    if (t.contains('tegangan') ||
        t.contains('panel') ||
        t.contains('daya') ||
        t.contains('listrik') ||
        t.contains('surya')) {
      return AppRoutePaths.power;
    }
    return null;
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    int? id,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, title: $title, isRead: $isRead)';
  }
}

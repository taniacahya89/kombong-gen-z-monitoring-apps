// lib/data/models/user_model.dart
//
// Model data untuk pengguna/autentikasi.
//
// Kontrak JSON response dari backend (AuthResponse):
// {
//   "token": "eyJhbG...",
//   "user": {
//     "id": 1,
//     "name": "Budi Santoso",
//     "email": "budi@gmail.com",
//     "role": "guest"   // atau "warga"
//   }
// }
//
// Field `role` digunakan oleh UI untuk logika RBAC:
//   - "guest": tampilkan tombol jadwal dalam keadaan disabled
//   - "warga": tampilkan dan aktifkan semua kontrol CRUD jadwal

class UserModel {
  final int? id;
  final String email;
  final String? name;
  final String? token;

  // Role menentukan hak akses di UI.
  // Nilai yang valid: 'guest' atau 'warga'.
  // Default 'guest' digunakan sebagai fallback jika backend belum return field ini.
  final String role;

  const UserModel({
    this.id,
    required this.email,
    this.name,
    this.token,
    this.role = 'guest',
  });

  // Mengembalikan true jika user adalah warga (memiliki akses CRUD jadwal).
  bool get isWarga => role == 'warga';

  // Mengembalikan true jika user adalah tamu (read-only).
  bool get isGuest => role == 'guest';

  // Request login (hanya email + password, tanpa expose password di model)
  static Map<String, dynamic> loginRequest({
    required String email,
    required String password,
  }) {
    return {
      'user': {
        'email': email,
        'password': password,
      },
    };
  }

  // Parsing dari response AuthResponse backend.
  // Backend mengembalikan dua struktur: dengan wrapper 'user' atau langsung.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Ambil token dari level teratas (jika ada)
    final token = json['token'] as String?;

    // Ambil data user dari sub-objek 'user'
    final userMap = json.containsKey('user')
        ? json['user'] as Map<String, dynamic>
        : json;

    return UserModel(
      id: userMap['id'] as int?,
      email: userMap['email'] as String,
      name: userMap['name'] as String?,
      token: token,
      role: (userMap['role'] as String?) ?? 'guest',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
    };
  }

  UserModel copyWith({
    int? id,
    String? email,
    String? name,
    String? token,
    String? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      token: token ?? this.token,
      role: role ?? this.role,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $name, role: $role)';
  }
}

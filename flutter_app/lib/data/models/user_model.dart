// lib/data/models/user_model.dart
//
// Model data pengguna untuk Firebase Auth.
// Tidak lagi menggunakan role-based access (semua user punya akses sama).

class UserModel {
  final String id;   // Firebase Auth UID
  final String email;
  final String? name;
  final String role;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
    required this.role,
  });

  bool get isWarga => role == 'warga';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      role: json['role'] as String? ?? 'warga',
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
    String? id,
    String? email,
    String? name,
    String? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }

  @override
  String toString() => 'UserModel(id: $id, email: $email, name: $name, role: $role)';
}

// lib/core/providers/auth_provider.dart
//
// State management untuk autentikasi pengguna menggunakan Riverpod.
//
// Arsitektur:
//   - authServiceProvider: Provider global yang menyediakan instance ApiService.
//     Bersifat singleton sehingga interceptor Dio hanya didaftarkan sekali.
//
//   - authStateProvider: StateNotifierProvider yang mengelola state autentikasi
//     (loading, sukses dengan UserModel, error). Menyimpan dan membaca token
//     dari secure storage via ApiService.
//
//   - authProvider: Alias mudah baca untuk authStateProvider.
//
// Penggunaan:
//   final auth = ref.watch(authProvider);
//   auth.when(
//     data: (user) => user != null ? Dashboard() : Login(),
//     loading: () => LoadingScreen(),
//     error: (e, _) => ErrorWidget(e.toString()),
//   );

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/services/api_service.dart';

// Provider global untuk instance ApiService (singleton).
final authServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

// State yang dipegang oleh AuthNotifier.
// null  -> belum login / sudah logout
// UserModel -> sudah login
typedef AuthState = AsyncValue<UserModel?>;

// Provider state autentikasi yang dapat didengarkan oleh semua widget.
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthNotifier(service);
});

/// AuthNotifier mengelola siklus hidup autentikasi:
///   - init: memeriksa token tersimpan saat startup
///   - login / register: autentikasi ke backend
///   - logout: menghapus token dan mereset state
///   - changePassword: mengubah kata sandi
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;

  AuthNotifier(this._api) : super(const AsyncValue.loading()) {
    // Periksa token tersimpan saat notifier pertama kali dibuat.
    // Ini memungkinkan auto-login jika token masih valid.
    _init();
  }

  // Periksa apakah user sudah pernah login (token tersimpan dan valid).
  Future<void> _init() async {
    try {
      final hasToken = await _api.hasToken();
      if (hasToken) {
        // Ambil data user terkini dari backend menggunakan token yang tersimpan.
        final user = await _api.getMe();
        state = AsyncValue.data(user);
      } else {
        // Tidak ada token; user perlu login.
        state = const AsyncValue.data(null);
      }
    } catch (_) {
      // Token mungkin kadaluarsa atau jaringan bermasalah; paksa logout.
      await _api.clearToken();
      state = const AsyncValue.data(null);
    }
  }

  /// Login dengan email dan password.
  /// Memperbarui state menjadi UserModel jika berhasil.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _api.login(email: email, password: password),
    );
  }

  /// Registrasi pengguna baru.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _api.register(name: name, email: email, password: password),
    );
  }

  /// Logout: menghapus token dan mereset state ke null.
  Future<void> logout() async {
    await _api.logout();
    state = const AsyncValue.data(null);
  }

  /// Mengubah kata sandi. Melempar exception jika gagal (ditangkap oleh UI).
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _api.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  /// Mengembalikan data UserModel yang sedang login, atau null jika belum login.
  UserModel? get currentUser => state.valueOrNull;
}

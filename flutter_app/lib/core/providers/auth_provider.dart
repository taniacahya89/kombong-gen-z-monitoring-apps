// lib/core/providers/auth_provider.dart
//
// State management untuk autentikasi pengguna menggunakan Riverpod dan Firebase.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/services/firebase_auth_service.dart';

// Provider global untuk instance FirebaseAuthService (singleton).
final authServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
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

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _init();
  }

  // Mendengarkan status autentikasi Firebase
  void _init() {
    _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        try {
          final profile = await _authService.getCurrentUserProfile();
          state = AsyncValue.data(profile);
        } catch (e) {
          state = AsyncValue.error(e, StackTrace.current);
        }
      } else {
        state = const AsyncValue.data(null);
      }
    });
  }

  /// Login dengan email dan password.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.login(email: email, password: password);
      state = AsyncValue.data(user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Registrasi pengguna baru.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.register(name: name, email: email, password: password);
      state = AsyncValue.data(user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Logout.
  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await _authService.logout();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Mengubah kata sandi.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _authService.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  /// Mengembalikan data UserModel yang sedang login, atau null jika belum login.
  UserModel? get currentUser => state.valueOrNull;
}


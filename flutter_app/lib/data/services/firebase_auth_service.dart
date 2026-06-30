// lib/data/services/firebase_auth_service.dart
//
// Service autentikasi menggunakan Firebase Authentication.
// Menggantikan sistem JWT + Dio yang sebelumnya digunakan.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentFirebaseUser => _auth.currentUser;

  Future<UserModel> login({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(), password: password);
    final firebaseUser = credential.user;
    if (firebaseUser == null) throw Exception('Login gagal.');
    final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
    final name = userDoc.data()?['name'] as String? ?? firebaseUser.displayName ?? 'Pengguna';
    final role = userDoc.data()?['role'] as String? ?? 'warga';
    return UserModel(id: firebaseUser.uid, email: firebaseUser.email ?? email, name: name, role: role);
  }

  Future<UserModel> register({required String name, required String email, required String password}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(), password: password);
    final firebaseUser = credential.user;
    if (firebaseUser == null) throw Exception('Registrasi gagal.');
    await firebaseUser.updateDisplayName(name);
    const role = 'warga'; // Default role for new registrations
    await _firestore.collection('users').doc(firebaseUser.uid).set({
      'name': name,
      'email': email.trim(),
      'role': role,
      'created_at': FieldValue.serverTimestamp(),
    });
    return UserModel(id: firebaseUser.uid, email: firebaseUser.email ?? email, name: name, role: role);
  }

  Future<void> logout() async => await _auth.signOut();

  Future<UserModel?> getCurrentUserProfile() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
    final name = userDoc.data()?['name'] as String? ?? firebaseUser.displayName ?? 'Pengguna';
    final role = userDoc.data()?['role'] as String? ?? 'warga';
    return UserModel(id: firebaseUser.uid, email: firebaseUser.email ?? '', name: name, role: role);
  }

  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || firebaseUser.email == null) throw Exception('Tidak ada user yang sedang login.');
    final credential = EmailAuthProvider.credential(email: firebaseUser.email!, password: oldPassword);
    await firebaseUser.reauthenticateWithCredential(credential);
    await firebaseUser.updatePassword(newPassword);
  }
}

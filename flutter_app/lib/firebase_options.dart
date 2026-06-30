// File generated manually to bypass FlutterFire CLI login errors.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBIWwgXhuv14lij_4nu_y5XBMzgTjcl-Vk',
    appId: '1:598204271499:web:58afc4f6c589cd4f8f5122',
    messagingSenderId: '598204271499',
    projectId: 'kandang-ayam-36d57',
    authDomain: 'kandang-ayam-36d57.firebaseapp.com',
    databaseURL: 'https://kandang-ayam-36d57-default-rtdb.firebaseio.com',
    storageBucket: 'kandang-ayam-36d57.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBIWwgXhuv14lij_4nu_y5XBMzgTjcl-Vk',
    appId: '1:598204271499:android:8f51224e8c50df5b347d8e',
    messagingSenderId: '598204271499',
    projectId: 'kandang-ayam-36d57',
    databaseURL: 'https://kandang-ayam-36d57-default-rtdb.firebaseio.com',
    storageBucket: 'kandang-ayam-36d57.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBIWwgXhuv14lij_4nu_y5XBMzgTjcl-Vk',
    appId: '1:598204271499:ios:8f51224e8c50df5b347d8e',
    messagingSenderId: '598204271499',
    projectId: 'kandang-ayam-36d57',
    databaseURL: 'https://kandang-ayam-36d57-default-rtdb.firebaseio.com',
    storageBucket: 'kandang-ayam-36d57.firebasestorage.app',
    iosBundleId: 'com.tania.kandangayam',
  );
}

// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web; // We are reusing the config from env
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: dotenv.env['VITE_FIREBASE_API_KEY'] ?? '',
        appId: dotenv.env['VITE_FIREBASE_APP_ID'] ?? '',
        messagingSenderId: dotenv.env['VITE_FIREBASE_MESSAGING_SENDER_ID'] ?? '',
        projectId: dotenv.env['VITE_FIREBASE_PROJECT_ID'] ?? '',
        authDomain: dotenv.env['VITE_FIREBASE_AUTH_DOMAIN'] ?? '',
        storageBucket: dotenv.env['VITE_FIREBASE_STORAGE_BUCKET'] ?? '',
      );
}

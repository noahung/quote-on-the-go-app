import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseStorage get storage => FirebaseStorage.instance;
  FirebaseMessaging? get messaging =>
      !kIsWeb ? FirebaseMessaging.instance : null;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _initialized = true;

      // Enable offline persistence for Firestore
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Configure FCM
      if (!kIsWeb && messaging != null) {
        await messaging!.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
      debugPrint('App will run without Firebase features.');
      _initialized = false;
    }
  }

  Future<String?> getFcmToken() async {
    if (kIsWeb || messaging == null) return null;
    try {
      return await messaging!.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  Stream<User?> get authStateChanges => auth.authStateChanges();
  Stream<User?> get userChanges => auth.userChanges();

  User? get currentUser => auth.currentUser;

  Future<void> signOut() async {
    await auth.signOut();
  }
}

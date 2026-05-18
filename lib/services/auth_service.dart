import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseService _firebaseService = FirebaseService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Stream<User?> get authStateChanges => _firebaseService.authStateChanges;
  User? get currentUser => _firebaseService.currentUser;

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final credential = await _firebaseService.auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await NotificationService().refreshTokenForCurrentUser();
    return credential;
  }

  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _firebaseService.auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result =
          await _firebaseService.auth.signInWithCredential(credential);
      await NotificationService().refreshTokenForCurrentUser();
      return result;
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseService.auth.sendPasswordResetEmail(email: email);
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseService.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> signOut() async {
    await NotificationService().clearToken();
    await _googleSignIn.signOut();
    await _firebaseService.signOut();
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc =
        await _firebaseService.firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  Stream<UserProfile?> streamUserProfile(String uid) {
    return _firebaseService.firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);
  }

  Future<void> createUserProfile(UserProfile profile) async {
    await _firebaseService.firestore.collection('users').doc(profile.uid).set({
      ...profile.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firebaseService.firestore.collection('users').doc(uid).update(data);
  }

  Future<Company?> getCompany(String companyId) async {
    final doc = await _firebaseService.firestore
        .collection('companies')
        .doc(companyId)
        .get();
    if (!doc.exists) return null;
    return Company.fromFirestore(doc);
  }

  Stream<Company?> streamCompany(String companyId) {
    return _firebaseService.firestore
        .collection('companies')
        .doc(companyId)
        .snapshots()
        .map((doc) => doc.exists ? Company.fromFirestore(doc) : null);
  }
}

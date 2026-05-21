import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'firebase_service.dart';

class OnboardingRepository {
  final FirebaseService _firebase = FirebaseService();

  Future<void> completeOnboarding({
    required String uid,
    required String displayName,
    required String email,
    required String companyName,
    required String companyEmail,
    String? companyPhone,
    String? companyAddress,
    File? logoFile,
  }) async {
    final firestore = _firebase.firestore;
    final companyRef = firestore.collection('companies').doc();
    final userRef = firestore.collection('users').doc(uid);

    // Upload logo first if provided (outside the transaction, as Storage is not transactional).
    // If upload fails (e.g. Storage rules not yet configured) we skip it gracefully —
    // the user can add their logo later from Company Branding settings.
    String? logoUrl;
    if (logoFile != null) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('companies/${companyRef.id}/logo.jpg');
        await storageRef.putFile(logoFile);
        logoUrl = await storageRef.getDownloadURL();
      } catch (_) {
        // Logo upload failed — proceed without it
        logoUrl = null;
      }
    }

    await firestore.runTransaction((transaction) async {
      // Guard: do not overwrite an existing profile
      final existingUser = await transaction.get(userRef);
      if (existingUser.exists) {
        throw Exception('User profile already exists.');
      }

      final now = FieldValue.serverTimestamp();

      transaction.set(companyRef, {
        'id': companyRef.id,
        'ownerId': uid,
        'name': companyName,
        'email': companyEmail,
        'phone': companyPhone ?? '',
        'address': companyAddress ?? '',
        if (logoUrl != null) 'logoUrl': logoUrl,
        'tier': 'free',
        'subscriptionStatus': 'active',
        'createdAt': now,
      });

      transaction.set(userRef, {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'emailVerified': true,
        'companyId': companyRef.id,
        'role': 'owner',
        'createdAt': now,
      });
    });
  }
}

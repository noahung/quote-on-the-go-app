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
    String? companyWebsite,
    required double defaultTaxRate,
    required double defaultHourlyRate,
    String? bankName,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankSortCode,
    required String pdfTemplate,
    required String pdfThemeColor,
    File? logoFile,
    String? referralCode,
  }) async {
    final firestore = _firebase.firestore;
    final companyRef = firestore.collection('companies').doc();
    final userRef = firestore.collection('users').doc(uid);

    // Upload logo first if provided
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

      // Referral handling (parity with web completeGoogleSignUp):
      // a valid referral code grants a 7-day premium trial to the new
      // company, and upgrades the referrer's company if not already premium.
      String tier = 'free';
      String subscriptionStatus = 'active';
      String? referredBy;
      Timestamp? trialEndsAt;
      DocumentReference<Map<String, dynamic>>? referrerCompanyRef;
      bool upgradeReferrer = false;

      final refCode = referralCode?.trim();
      if (refCode != null && refCode.isNotEmpty) {
        try {
          final referrerUserSnap =
              await transaction.get(firestore.collection('users').doc(refCode));
          if (referrerUserSnap.exists) {
            tier = 'premium';
            subscriptionStatus = 'referral_trial';
            referredBy = refCode;
            trialEndsAt = Timestamp.fromDate(
                DateTime.now().add(const Duration(days: 7)));

            final referrerData = referrerUserSnap.data();
            final referrerCompanyId = referrerData?['companyId'] as String?;
            if (referrerCompanyId != null) {
              referrerCompanyRef =
                  firestore.collection('companies').doc(referrerCompanyId);
              final referrerCompanySnap =
                  await transaction.get(referrerCompanyRef);
              if (referrerCompanySnap.exists) {
                final companyData = referrerCompanySnap.data();
                upgradeReferrer = companyData?['tier'] != 'premium';
              }
            }
          }
        } catch (_) {
          // Invalid or unreadable referral code — proceed without referral bonus
        }
      }

      final now = FieldValue.serverTimestamp();

      transaction.set(companyRef, {
        'id': companyRef.id,
        'ownerId': uid,
        'name': companyName,
        'email': companyEmail,
        'phone': companyPhone ?? '',
        'address': companyAddress ?? '',
        'website': companyWebsite ?? '',
        'defaultTaxRate': defaultTaxRate,
        'defaultHourlyRate': defaultHourlyRate,
        'defaultPdfTemplateId': pdfTemplate,
        'defaultPdfThemeColor': pdfThemeColor,
        'onboardingCompleted': true,
        if (logoUrl != null) 'logoUrl': logoUrl,
        'tier': tier,
        'subscriptionStatus': subscriptionStatus,
        if (referredBy != null) 'referredBy': referredBy,
        if (trialEndsAt != null) 'trialEndsAt': trialEndsAt,
        'createdAt': now,
        if (bankName != null ||
            bankAccountName != null ||
            bankAccountNumber != null ||
            bankSortCode != null)
          'bankAccounts': [
            {
              'id': 'primary',
              'bankName': bankName ?? '',
              'accountName': bankAccountName ?? '',
              'sortCode': bankSortCode ?? '',
              'accountNumber': bankAccountNumber ?? '',
            }
          ],
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

      // Upgrade referrer's company with a matching premium trial
      if (upgradeReferrer && referrerCompanyRef != null) {
        transaction.update(referrerCompanyRef, {
          'tier': 'premium',
          'subscriptionStatus': 'referral_trial',
          'trialEndsAt': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 7))),
        });
      }
    });

    // Send welcome email (fire-and-forget, parity with web sendWelcomeEmailAction)
    try {
      await firestore.collection('mail').add({
        'to': email,
        'message': {
          'subject': 'Welcome to Quote On The Go!',
          'html': '''
<p>Hi $displayName,</p>
<p>Welcome to <strong>Quote On The Go</strong>! Your workspace for <strong>$companyName</strong> is ready.</p>
<p>You can now create quotations, send invoices, and manage your customers on the go.</p>
<p>Happy quoting!<br/>The Quote On The Go Team</p>
''',
        },
      });
    } catch (_) {
      // Welcome email failure should not block onboarding
    }
  }
}

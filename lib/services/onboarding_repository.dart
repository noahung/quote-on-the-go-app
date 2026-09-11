import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'api_client.dart';

class OnboardingRepository {
  OnboardingRepository(
      {Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
          post})
      : _post = post ?? ApiClient.post;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
      _post;
  Future<void> completeOnboarding({
    required String uid,
    required String displayName,
    String? userPhone,
    String? jobTitle,
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
    final result = await _post('/api/mobile/onboarding', {
      'displayName': displayName,
      'companyName': companyName,
      'companyEmail': companyEmail,
      'userPhone': userPhone,
      'jobTitle': jobTitle,
      'companyPhone': companyPhone,
      'companyAddress': companyAddress,
      'companyWebsite': companyWebsite,
      'defaultTaxRate': defaultTaxRate,
      'defaultHourlyRate': defaultHourlyRate,
      'bankName': bankName,
      'bankAccountName': bankAccountName,
      'bankAccountNumber': bankAccountNumber,
      'bankSortCode': bankSortCode,
      'pdfTemplate': pdfTemplate,
      'pdfThemeColor': pdfThemeColor,
      'referralCode': referralCode,
    });
    if (logoFile != null) {
      final companyId = result['companyId'] as String;
      final storageRef =
          FirebaseStorage.instance.ref('companies/$companyId/logo.jpg');
      await storageRef.putFile(logoFile);
      final logoUrl = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .update({'logoUrl': logoUrl});
    }
  }
}

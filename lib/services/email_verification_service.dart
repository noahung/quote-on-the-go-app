import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EmailVerificationService {
  String get _baseUrl {
    final url =
        dotenv.maybeGet('APP_BASE_URL') ?? 'https://app.quoteonthego.co.uk';
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<String?> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<({bool success, String? error})> sendCode({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    try {
      final idToken = await _getIdToken();
      if (idToken == null) {
        return (success: false, error: 'User is not authenticated.');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/send-verification-code'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'uid': uid,
          'email': email,
          'displayName': displayName,
        }),
      );

      if (response.statusCode == 200) {
        return (success: true, error: null);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (
        success: false,
        error: body['error'] as String? ?? 'Failed to send verification code.'
      );
    } catch (e) {
      return (success: false, error: 'Network error: ${e.toString()}');
    }
  }

  Future<({bool success, String? error})> verifyCode({
    required String uid,
    required String code,
  }) async {
    try {
      final idToken = await _getIdToken();
      if (idToken == null) {
        return (success: false, error: 'User is not authenticated.');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/verify-code'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'uid': uid,
          'code': code,
        }),
      );

      if (response.statusCode == 200) {
        // Reload the Firebase Auth user so emailVerified is updated locally
        await FirebaseAuth.instance.currentUser?.reload();
        return (success: true, error: null);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (
        success: false,
        error: body['error'] as String? ?? 'Verification failed.'
      );
    } catch (e) {
      return (success: false, error: 'Network error: ${e.toString()}');
    }
  }
}

final emailVerificationService = EmailVerificationService();

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  bool get retryable =>
      statusCode == 408 || statusCode == 429 || statusCode >= 500;
  @override
  String toString() => message;
}

class ApiClient {
  static String get baseUrl {
    final value = dotenv.isInitialized ? dotenv.maybeGet('APP_BASE_URL') : null;
    return (value ?? 'https://app.quoteonthego.co.uk')
        .replaceFirst(RegExp(r'/+$'), '');
  }

  static Future<Map<String, String>> headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Please sign in again.');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    };
  }

  static Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    final response = await http
        .post(Uri.parse('$baseUrl$path'),
            headers: await headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
          'The service is unavailable. Please try again.', response.statusCode);
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] == false) {
      throw ApiException(
          data['error'] ?? 'The request failed. Please try again.',
          response.statusCode);
    }
    return data;
  }
}

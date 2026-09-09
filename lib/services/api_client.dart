import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static String get baseUrl {
    final value = dotenv.isInitialized ? dotenv.maybeGet('APP_BASE_URL') : null;
    return (value ?? 'https://app.quoteonthego.co.uk').replaceFirst(RegExp(r'/+$'), '');
  }

  static Future<Map<String, String>> headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Please sign in again.');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl$path'),
      headers: await headers(), body: jsonEncode(body)).timeout(const Duration(seconds: 60));
    Map<String, dynamic> data;
    try { data = jsonDecode(response.body) as Map<String, dynamic>; }
    catch (_) { throw Exception('The service is unavailable. Please try again.'); }
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] == false) {
      throw Exception(data['error'] ?? 'The request failed. Please try again.');
    }
    return data;
  }
}

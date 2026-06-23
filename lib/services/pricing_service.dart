import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PricingService {
  String get _baseUrl {
    final url = dotenv.maybeGet('APP_BASE_URL') ?? 'https://app.quoteonthego.co.uk';
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<String> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final token = await user.getIdToken();
    if (token == null) throw Exception('Failed to get ID token');
    return token;
  }

  Future<List<Map<String, dynamic>>> generatePricingSuggestions({String? serviceId}) async {
    final idToken = await _getIdToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/pricing/suggestions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            if (serviceId != null) 'serviceId': serviceId,
          }),
        )
        .timeout(const Duration(seconds: 60));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to generate pricing suggestions');
    }
    final suggestions = data['suggestions'] as List<dynamic>? ?? [];
    return suggestions.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> generateServiceBundles() async {
    final idToken = await _getIdToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/pricing/bundles'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        )
        .timeout(const Duration(seconds: 60));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to generate service bundles');
    }
    final bundles = data['bundles'] as List<dynamic>? ?? [];
    return bundles.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> generateDiscountRecommendation({required String quotationId}) async {
    final idToken = await _getIdToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/pricing/discount'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'quotationId': quotationId}),
        )
        .timeout(const Duration(seconds: 60));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to generate discount recommendation');
    }
    return data['recommendation'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> analyzeReceipt({required String imageBase64}) async {
    final idToken = await _getIdToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/ai/analyze-receipt'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'imageBase64': imageBase64}),
        )
        .timeout(const Duration(seconds: 60));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to analyze receipt');
    }
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'AI analysis failed');
    }
    return data['data'] as Map<String, dynamic>;
  }
}

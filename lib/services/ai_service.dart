import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class AIService {
  /// Generates line items using AI based on a job description
  /// Returns a list of LineItems or throws an exception on error
  Future<List<LineItem>> generateLineItems({
    required String prompt,
    required String companyId,
  }) async {
    try {
      // Get current user's ID token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      final idToken = await user.getIdToken();

      // Simple HTTP POST like the web app
      final response = await http
          .post(
            Uri.parse(
                'https://us-central1-adverto-invoice.cloudfunctions.net/generateLineItems'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'prompt': prompt,
              'companyId': companyId,
              'idToken': idToken,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception(data['error'] ??
            'Failed to generate items (code: ${response.statusCode})');
      }

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to generate items');
      }

      final items = data['items'] as List<dynamic>? ?? [];

      return items
          .map((item) => LineItem(
                id: DateTime.now().millisecondsSinceEpoch.toString() +
                    (item['description'] as String).hashCode.toString(),
                description: item['description'] as String,
                quantity: (item['quantity'] as num).toDouble(),
                unitPrice: (item['unitPrice'] as num).toDouble(),
                total: ((item['quantity'] as num) * (item['unitPrice'] as num))
                    .toDouble(),
                itemDetails: item['itemDetails'] as String?,
              ))
          .toList();
    } on SocketException catch (e) {
      debugPrint('[AI_SERVICE] Network error: $e');
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      debugPrint('[AI_SERVICE] Unexpected error: $e');
      throw Exception('Failed to generate items. Please try again.');
    }
  }
}

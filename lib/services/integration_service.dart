import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class IntegrationService {
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

  Future<String> connectQuickBooks({required String companyId}) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/quickbooks/connect'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'companyId': companyId}),
        )
        .timeout(const Duration(seconds: 30));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to connect QuickBooks');
    }
    return data['authUrl'] as String;
  }

  Future<void> disconnectQuickBooks({required String companyId}) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/quickbooks/disconnect'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'companyId': companyId}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['error'] ?? 'Failed to disconnect QuickBooks');
    }
  }

  Future<String> connectMonday() async {
    final idToken = await _getIdToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/monday/connect'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        )
        .timeout(const Duration(seconds: 30));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to connect Monday.com');
    }
    return data['authUrl'] as String;
  }

  Future<void> disconnectMonday() async {
    final idToken = await _getIdToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/monday/disconnect'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['error'] ?? 'Failed to disconnect Monday.com');
    }
  }

  Future<List<Map<String, dynamic>>> getMondayBoards() async {
    final idToken = await _getIdToken();
    final response = await http
        .get(
          Uri.parse('$_baseUrl/api/monday/boards'),
          headers: {'Authorization': 'Bearer $idToken'},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Failed to load Monday.com boards');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final boards = data['boards'] as List<dynamic>? ?? [];
    return boards.cast<Map<String, dynamic>>();
  }

  Future<void> configureMondayBoards({
    String? quotationsBoardId,
    String? invoicesBoardId,
    String? customersBoardId,
  }) async {
    final idToken = await _getIdToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/monday/configure'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            if (quotationsBoardId != null)
              'quotationsBoardId': quotationsBoardId,
            if (invoicesBoardId != null)
              'invoicesBoardId': invoicesBoardId,
            if (customersBoardId != null)
              'customersBoardId': customersBoardId,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Failed to save board configuration');
    }
  }

  Future<void> disconnectGoogleCalendar({required String companyId}) async {
    await FirebaseFirestore.instance.collection('companies').doc(companyId).update({
      'googleCalendarRefreshToken': FieldValue.delete(),
      'googleCalendarEnabled': false,
      'googleCalendarConnectedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String getGoogleCalendarConnectUrl() {
    return '$_baseUrl/settings/integrations';
  }

  Future<String> connectXero({required String companyId}) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/xero/connect'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'companyId': companyId, 'platform': 'mobile'}),
        )
        .timeout(const Duration(seconds: 30));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to connect Xero');
    }
    return data['authUrl'] as String;
  }

  Future<void> disconnectXero({required String companyId}) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/xero/disconnect'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'companyId': companyId}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['error'] ?? 'Failed to disconnect Xero');
    }
  }

  Future<Map<String, dynamic>> syncXero({
    required String companyId,
    String action = 'full',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/xero/sync'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'companyId': companyId,
            'action': action,
            'userId': user?.uid ?? '',
          }),
        )
        .timeout(const Duration(seconds: 60));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to sync with Xero');
    }
    return data;
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TeamService {
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

  Future<void> removeMember({required String userId}) async {
    final idToken = await _getIdToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/team/remove-member'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'userId': userId}),
        )
        .timeout(const Duration(seconds: 30));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to remove member');
    }
  }

  Future<void> changeRole({required String userId, required String newRole}) async {
    final idToken = await _getIdToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/team/change-role'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'userId': userId, 'newRole': newRole}),
        )
        .timeout(const Duration(seconds: 30));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to change role');
    }
  }

  Future<void> cancelInvitation({required String invitationId}) async {
    final idToken = await _getIdToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/team/cancel-invitation'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'invitationId': invitationId}),
        )
        .timeout(const Duration(seconds: 30));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to cancel invitation');
    }
  }

  Future<int> cleanupExpiredInvitations() async {
    final idToken = await _getIdToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/team/cleanup-expired'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        )
        .timeout(const Duration(seconds: 30));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to cleanup');
    }
    return (data['cleaned'] as num?)?.toInt() ?? 0;
  }
}

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AdminService {
  static const String baseUrl = 'https://dreamhunter-api.onrender.com';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final http.Client _client = http.Client();

  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getIdToken();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Checks if the backend is reachable and returns the latency in ms if successful.
  /// Returns null if the ping fails.
  Future<int?> pingServer() async {
    try {
      final stopwatch = Stopwatch()..start();
      final response = await _client
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();

      if (response.statusCode == 200) {
        return stopwatch.elapsedMilliseconds;
      }
      return null;
    } catch (e) {
      debugPrint('Server ping failed: $e');
      return null;
    }
  }

  // --- Maintenance & Broadcast ---

  Stream<DocumentSnapshot> getSystemConfig() {
    return _db.collection('metadata').doc('system_config').snapshots();
  }

  Future<bool> updateMaintenance(
    bool? chatMaintenance,
    bool? shopMaintenance,
  ) async {
    try {
      final Map<String, dynamic> bodyData = {};
      if (chatMaintenance != null) {
        bodyData['chatMaintenance'] = chatMaintenance;
      }
      if (shopMaintenance != null) {
        bodyData['shopMaintenance'] = shopMaintenance;
      }

      final response = await _client.patch(
        Uri.parse('$baseUrl/admin/maintenance'),
        headers: await getAuthHeaders(),
        body: json.encode(bodyData),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating maintenance: $e');
      return false;
    }
  }

  Future<bool> sendGlobalBroadcast(String message, bool isPersistent) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/admin/broadcast'),
        headers: await getAuthHeaders(),
        body: json.encode({'message': message, 'isPersistent': isPersistent}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending broadcast: $e');
      return false;
    }
  }

  // --- Player Management ---

  Future<List<dynamic>> searchPlayers({
    String? query,
    bool? isBanned,
    bool? isAdmin,
  }) async {
    try {
      String url = '$baseUrl/admin/players/search?';
      if (query != null && query.isNotEmpty) url += 'query=$query&';
      if (isBanned != null) url += 'isBanned=$isBanned&';
      if (isAdmin != null) url += 'isAdmin=$isAdmin&';

      final response = await _client.get(
        Uri.parse(url),
        headers: await getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 403) {
        throw Exception('Admin privileges required.');
      }
      return [];
    } catch (e) {
      debugPrint('Error searching players: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/admin/users/$uid'),
        headers: await getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  Future<bool> banUser(String uid, bool isBanned, {String? until}) async {
    try {
      final response = await _client.patch(
        Uri.parse('$baseUrl/admin/users/$uid/ban'),
        headers: await getAuthHeaders(),
        body: json.encode({'isBanned': isBanned, 'until': ?until}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error banning user: $e');
      return false;
    }
  }

  Future<bool> muteUser(String uid, int? durationHours, {String? until}) async {
    try {
      final response = await _client.patch(
        Uri.parse('$baseUrl/admin/users/$uid/mute'),
        headers: await getAuthHeaders(),
        body: json.encode({'durationHours': ?durationHours, 'until': ?until}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error muting user: $e');
      return false;
    }
  }

  // --- Reports ---

  Future<List<dynamic>> getReports(String? status) async {
    try {
      String url = '$baseUrl/admin/reports';
      if (status != null) url += '?status=$status';
      final response = await _client.get(
        Uri.parse(url),
        headers: await getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('Error getting reports: $e');
      return [];
    }
  }

  Future<bool> updateReportStatus(String reportId, String status) async {
    try {
      final response = await _client.patch(
        Uri.parse('$baseUrl/admin/reports/$reportId?status=$status'),
        headers: await getAuthHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating report status: $e');
      return false;
    }
  }

  // --- Auto-Mod ---

  Stream<DocumentSnapshot> getAutoModConfigStream() {
    return _db.collection('metadata').doc('moderation_config').snapshots();
  }

  Future<bool> updateAutoModConfig(Map<String, dynamic> config) async {
    try {
      final response = await _client.patch(
        Uri.parse('$baseUrl/admin/automod/config'),
        headers: await getAuthHeaders(),
        body: json.encode(config),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating automod config: $e');
      return false;
    }
  }

  // --- Audit Logs ---

  Future<List<dynamic>> getAuditLogs() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/admin/audit-logs'),
        headers: await getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('Error getting audit logs: $e');
      return [];
    }
  }
}

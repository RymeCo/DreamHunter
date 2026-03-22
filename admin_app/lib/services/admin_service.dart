import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

class AdminService {
  static const String baseUrl = 'https://dreamhunter-api.onrender.com';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final http.Client _client = http.Client();

  User? get currentUser => _auth.currentUser;

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

  // --- Maintenance & Broadcast ---

  Stream<DocumentSnapshot> getSystemConfig() {
    return _db.collection('metadata').doc('system_config').snapshots();
  }

  Future<bool> updateMaintenance({
    bool? chatMaintenance,
    bool? shopMaintenance,
    bool? syncMaintenance,
  }) async {
    try {
      final Map<String, dynamic> bodyData = {
        'chatMaintenance': chatMaintenance,
        'shopMaintenance': shopMaintenance,
        'syncMaintenance': syncMaintenance,
      };

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
    int limit = 20,
    String? lastId,
  }) async {
    try {
      String url = '$baseUrl/admin/players/search?limit=$limit&';
      if (query != null && query.isNotEmpty) url += 'query=$query&';
      if (isBanned != null) url += 'isBanned=$isBanned&';
      if (isAdmin != null) url += 'isAdmin=$isAdmin&';
      if (lastId != null) url += 'lastId=$lastId&';

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

  Future<bool> banUser(String uid, bool isBanned, {bool isSuperBanned = false, String? until}) async {
    try {
      final response = await _client.patch(
        Uri.parse('$baseUrl/admin/users/$uid/ban'),
        headers: await getAuthHeaders(),
        body: json.encode({
          'isBanned': isBanned, 
          'isSuperBanned': isSuperBanned,
          'until': until
        }),
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
        body: json.encode({'durationHours': durationHours, 'until': until}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error muting user: $e');
      return false;
    }
  }

  Future<bool> warnUser(String uid, String reason) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/admin/users/$uid/warnings'),
        headers: await getAuthHeaders(),
        body: json.encode({'reason': reason}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error warning user: $e');
      return false;
    }
  }

  Future<bool> updatePlayerCurrency(
    String uid, {
    int? dreamCoins,
    int? hellStones,
  }) async {
    try {
      final response = await _client.patch(
        Uri.parse('$baseUrl/admin/users/$uid/currency'),
        headers: await getAuthHeaders(),
        body: json.encode({
          'dreamCoins': dreamCoins,
          'hellStones': hellStones,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating currency: $e');
      return false;
    }
  }

  Future<bool> updateModeratorStatus(String uid, bool isModerator) async {
    try {
      final response = await _client.patch(
        Uri.parse('$baseUrl/admin/users/$uid/role'),
        headers: await getAuthHeaders(),
        body: json.encode({'isModerator': isModerator}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating moderator status: $e');
      return false;
    }
  }

  Future<bool> resetSpamScore(String uid) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/admin/users/$uid/reset-spam'),
        headers: await getAuthHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error resetting spam score: $e');
      return false;
    }
  }

  Future<bool> requestBan(String targetUid, {required String reason}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/admin/reports'),
        headers: await getAuthHeaders(),
        body: json.encode({
          'targetUid': targetUid,
          'reason': reason,
          'type': 'MODERATOR_REQUEST',
          'priority': 'CRITICAL',
          'status': 'pending',
          'reportTimestamp': DateTime.now().toUtc().toIso8601String()
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error requesting ban: $e');
      return false;
    }
  }

  Future<bool> warnUser(String uid, String reason) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/admin/users/$uid/warnings'),
        headers: await getAuthHeaders(),
        body: json.encode({'reason': reason}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error warning user: $e');
      return false;
    }
  }

  Future<bool> updateModeratorStatus(String uid, bool isModerator) async {
    try {
      final response = await _client.patch(
        Uri.parse('$baseUrl/admin/users/$uid/role'),
        headers: await getAuthHeaders(),
        body: json.encode({'isModerator': isModerator}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating moderator status: $e');
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

  // --- Stats ---

  Future<Map<String, dynamic>?> getStatsSummary() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/admin/stats/summary'),
        headers: await getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorMsg =
            'Server returned ${response.statusCode}: ${response.body}';
        debugPrint(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error getting stats summary: $e');
      rethrow;
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

  // --- Live Chat ---

  Stream<QuerySnapshot> getLiveChatStream(String region) {
    return _db
        .collection('chats')
        .doc(region)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<void> toggleLikeMessage(
    String region,
    String messageId, {
    required bool isAdmin,
    required bool isModerator,
    required bool currentAdminLiked,
    required bool currentModLiked,
  }) async {
    try {
      // Logic for determining value: toggle the current state based on role
      final bool newValue = isAdmin ? !currentAdminLiked : !currentModLiked;
      
      await _client.post(
        Uri.parse('$baseUrl/admin/chats/message/action'),
        headers: await getAuthHeaders(),
        body: json.encode({
          'region': region,
          'messageId': messageId,
          'action': 'like',
          'value': newValue
        }),
      );
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> toggleDislikeMessage(
    String region,
    String messageId, {
    required bool currentDisliked,
  }) async {
    try {
      await _client.post(
        Uri.parse('$baseUrl/admin/chats/message/action'),
        headers: await getAuthHeaders(),
        body: json.encode({
          'region': region,
          'messageId': messageId,
          'action': 'hide',
          'value': !currentDisliked
        }),
      );
    } catch (e) {
      debugPrint('Error toggling dislike: $e');
    }
  }

  Future<bool> sendGhostMessage(
    String region,
    String text,
    String ghostName,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/admin/chats/message/send'),
        headers: await getAuthHeaders(),
        body: json.encode({
          'region': region,
          'text': text,
          'senderName': ghostName,
          'isGhost': true,
          'isSystem': false
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending ghost message: $e');
      return false;
    }
  }

  Future<bool> sendSystemBroadcastToChat(String region, String text) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/admin/chats/message/send'),
        headers: await getAuthHeaders(),
        body: json.encode({
          'region': region,
          'text': text,
          'senderName': 'System',
          'isGhost': false,
          'isSystem': true
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending system broadcast: $e');
      return false;
    }
  }

  Future<bool> sendSystemBroadcastToAllRegions(String text) async {
    final regions = ['english', 'spanish', 'chinese', 'russian', 'tagalog'];
    bool allSuccess = true;
    for (final region in regions) {
      final success = await sendSystemBroadcastToChat(region, text);
      if (!success) allSuccess = false;
    }
    return allSuccess;
  }

  // --- Batch Actions ---

  Future<bool> performBatchAction(
    List<String> uids,
    String action, {
    Map<String, dynamic>? params,
  }) async {
    try {
      final response = await _client.patch(
        Uri.parse('$baseUrl/admin/users/batch-action'),
        headers: await getAuthHeaders(),
        body: json.encode({'uids': uids, 'action': action, 'params': params}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error performing batch action: $e');
      return false;
    }
  }

  Future<bool> updatePlayerSave(
    String uid, {
    int? level,
    int? xp,
    bool? forceSyncNext,
  }) async {
    try {
      final response = await _client.patch(
        Uri.parse('$baseUrl/admin/users/$uid/save'),
        headers: await getAuthHeaders(),
        body: json.encode({
          'level': level,
          'xp': xp,
          'forceSyncNext': forceSyncNext,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating player save: $e');
      return false;
    }
  }

  Future<bool> forcePlayerSync(String uid) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/admin/users/$uid/force-sync'),
        headers: await getAuthHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error forcing player sync: $e');
      return false;
    }
  }

  /// Fetches the leaderboard data
  Future<List<dynamic>?> getLeaderboard(String criteria, {int limit = 10}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/leaderboard/top?by=$criteria&limit=$limit'),
        headers: await getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      return null;
    }
  }
}

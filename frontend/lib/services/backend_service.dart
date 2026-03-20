import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class BackendService {
  static const String baseUrl = 'https://dreamhunter-api.onrender.com';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final http.Client _client;

  BackendService({http.Client? client}) : _client = client ?? http.Client();

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

  /// Helper for authenticated GET requests
  Future<http.Response> get(String path) async {
    final headers = await getAuthHeaders();
    return await _client.get(Uri.parse('$baseUrl$path'), headers: headers);
  }

  /// Helper for authenticated POST requests
  Future<http.Response> post(String path, {Object? body}) async {
    final headers = await getAuthHeaders();
    return await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
  }

  /// Helper for authenticated PATCH requests
  Future<http.Response> patch(String path, {Object? body}) async {
    final headers = await getAuthHeaders();
    return await _client.patch(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
  }

  /// Checks if the backend is reachable
  Future<bool> pingServer() async {
    try {
      final response = await _client.get(Uri.parse(baseUrl)).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Server ping failed: $e');
      return false;
    }
  }

  /// Syncs the user profile with the backend after login or register
  Future<Map<String, dynamic>?> syncUserProfile() async {
    try {
      final response = await get('/user/profile');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Backend sync failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error syncing with backend: $e');
      return null;
    }
  }

  /// Updates the user's display name in the backend
  Future<bool> updateDisplayName(String newName) async {
    try {
      final response = await patch('/users/display-name?name=$newName');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating name in backend: $e');
      return false;
    }
  }

  /// Synchronizes local economy state with the backend
  Future<Map<String, dynamic>?> syncEconomy(int dreamCoins, int hellStones) async {
    try {
      final response = await post(
        '/economy/sync',
        body: {'dreamCoins': dreamCoins, 'hellStones': hellStones},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error syncing economy: $e');
      return null;
    }
  }

  /// Converts Hell Stones to Dream Coins
  Future<Map<String, dynamic>?> convertCurrency(int hellStones) async {
    try {
      final response = await post('/economy/convert?hell_stones=$hellStones');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error converting currency: $e');
      return null;
    }
  }
}

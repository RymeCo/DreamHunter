import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class BackendService {
  // Replace this with your actual Render URL after deployment
  // For local testing on WayDroid, use 10.0.2.2 instead of localhost
  static const String _baseUrl = 'https://dreamhunter-api.onrender.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Gets the current user's Firebase ID token
  Future<String?> _getIdToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  /// Syncs the user profile with the backend after login or register
  Future<Map<String, dynamic>?> syncUserProfile() async {
    try {
      final token = await _getIdToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/user/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
      final token = await _getIdToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/user/update_display_name?name=$newName'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating name in backend: $e');
      return false;
    }
  }
}

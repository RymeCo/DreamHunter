import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dreamhunter/services/core/storage_engine.dart';

/// The bridge between the Flutter frontend and the FastAPI backend.
class ApiGateway {
  /// TODO: Replace with your actual Render.com URL after deployment.
  static const String baseUrl = 'https://dreamhunter-api.onrender.com/api';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fetches the ID token, prioritizing the local cache for O(1) speed.
  Future<String?> getIdToken() async {
    // 1. Try local cache first (Instant)
    final cached = StorageEngine.instance.getCachedToken();
    if (cached != null) return cached;

    // 2. Fallback to Firebase (Network)
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final token = await user.getIdToken();
    if (token != null) {
      // Pre-warm the cache for the next call
      await StorageEngine.instance.saveCachedToken(token);
    }
    return token;
  }

  /// Generates headers with the Bearer token.
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // Live Handlers
  Future<http.Response> get(String path) async {
    final url = Uri.parse('$baseUrl$path');
    return await http.get(url, headers: await getAuthHeaders());
  }

  Future<http.Response> post(String path, {Object? body}) async {
    final url = Uri.parse('$baseUrl$path');
    return await http.post(
      url,
      headers: await getAuthHeaders(),
      body: json.encode(body),
    );
  }

  Future<http.Response> patch(String path, {Object? body}) async {
    final url = Uri.parse('$baseUrl$path');
    return await http.patch(
      url,
      headers: await getAuthHeaders(),
      body: json.encode(body),
    );
  }

  /// Triggers a full sync of player data to the backend.
  Future<bool> performFullSync(Map<String, dynamic> playerData) async {
    final response = await patch('/profile/update', body: playerData);
    return response.statusCode == 200;
  }
}

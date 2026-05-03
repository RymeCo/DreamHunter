import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// The bridge between the Flutter frontend and the FastAPI backend.
class ApiGateway {
  /// TODO: Replace with your actual Render.com URL after deployment.
  static const String baseUrl = 'https://dreamhunter-api.onrender.com/api';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fetches the fresh ID token from Firebase.
  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken(true);
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

import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendService {
  static const String baseUrl = 'http://localhost:8000'; // Mock base URL

  BackendService({http.Client? client});

  Future<String?> getIdToken() async {
    return 'mock_token';
  }

  Future<Map<String, String>> getAuthHeaders() async {
    return {
      'Authorization': 'Bearer mock_token',
      'Content-Type': 'application/json',
    };
  }

  Future<http.Response> get(String path) async {
    return http.Response(json.encode({'status': 'success'}), 200);
  }

  Future<http.Response> post(String path, {Object? body}) async {
    return http.Response(json.encode({'status': 'success'}), 200);
  }

  Future<http.Response> patch(String path, {Object? body}) async {
    return http.Response(json.encode({'status': 'success'}), 200);
  }

  Future<Map<String, dynamic>> sendMessage(String text) async {
    return {'status': 'success', 'message': 'Message sent (Offline mode)'};
  }

  Future<Map<String, dynamic>?> syncUserProfile() async {
    return null;
  }

  Future<bool> performFullSync() async {
    return true;
  }
}

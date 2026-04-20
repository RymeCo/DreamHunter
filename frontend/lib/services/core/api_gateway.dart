import 'dart:convert';
import 'package:http/http.dart' as http;

/// A minimalist Mock service that simulates backend responses.
/// Useful for UI development without a live server.
class ApiGateway {
  // Minimal mock logic: Always returns success.
  Future<http.Response> _mockSuccess() async =>
      http.Response(json.encode({'status': 'success'}), 200);

  Future<String> getIdToken() async => 'mock_token';

  Future<Map<String, String>> getAuthHeaders() async => {
    'Authorization': 'Bearer ${await getIdToken()}',
    'Content-Type': 'application/json',
  };

  // Generic Mock Handlers
  Future<http.Response> get(String path) => _mockSuccess();
  Future<http.Response> post(String path, {Object? body}) => _mockSuccess();

  // Feature-specific Mock Responses
  Future<Map<String, dynamic>> sendMessage(String text) async => {
    'status': 'success',
    'message': 'Message sent (Offline)',
  };

  Future<bool> performFullSync() async => true;
}

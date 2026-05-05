import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiGateway {
  static const String baseUrl = 'https://dreamhunter-api.onrender.com/api';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, String>> getAuthHeaders() async {
    final user = _auth.currentUser;
    final token = await user?.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

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
}

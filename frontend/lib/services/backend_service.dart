import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'offline_cache.dart';

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

  /// Helper for authenticated requests with retry logic
  Future<http.Response> _authenticatedRequest(
    String method,
    String path, {
    Object? body,
    int retries = 3,
  }) async {
    final url = Uri.parse('$baseUrl$path');
    int attempt = 0;
    
    while (attempt < retries) {
      try {
        final headers = await getAuthHeaders();
        http.Response response;
        
        switch (method) {
          case 'POST':
            response = await _client.post(url, headers: headers, body: body != null ? json.encode(body) : null);
            break;
          case 'PATCH':
            response = await _client.patch(url, headers: headers, body: body != null ? json.encode(body) : null);
            break;
          case 'GET':
          default:
            response = await _client.get(url, headers: headers);
        }
        
        // If server is waking up (Render cold start) or other 5xx, retry
        if (response.statusCode >= 500 && attempt < retries - 1) {
          attempt++;
          await Future.delayed(Duration(seconds: 2 * attempt));
          continue;
        }
        return response;
      } catch (e) {
        attempt++;
        if (attempt >= retries) rethrow;
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
    throw Exception('Request failed after $retries attempts');
  }

  /// Helper for authenticated GET requests
  Future<http.Response> get(String path) => _authenticatedRequest('GET', path);

  /// Helper for authenticated POST requests
  Future<http.Response> post(String path, {Object? body}) => _authenticatedRequest('POST', path, body: body);

  /// Helper for authenticated PATCH requests
  Future<http.Response> patch(String path, {Object? body}) => _authenticatedRequest('PATCH', path, body: body);

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

  /// Performs a full cloud sync: Reconciles economy and updates profile/progress
  Future<bool> performFullSync() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    bool success = false;
    try {
      // 1. Reconcile Economy
      final transactions = await OfflineCache.getTransactionQueue();
      if (transactions.isNotEmpty) {
        final List<String> sentIds = transactions.map((t) => t.id).toList();
        final result = await reconcileEconomy(transactions.map((t) => t.toJson()).toList());
        
        if (result != null && result['status'] == 'success') {
          await OfflineCache.clearTransactionQueue(ids: sentIds);
          await OfflineCache.saveCurrency(
            result['dreamCoins'] as int,
            result['hellStones'] as int,
            result['playtime'] as int? ?? 0,
            result['freeSpins'] as int? ?? 0,
            result['xp'] as int? ?? 0,
            result['level'] as int? ?? 1,
          );
          
          if (result['levelUp'] == true) {
             // We can't easily show a snackbar from here without context, 
             // but we'll return a special status or just let the HUD update.
             debugPrint('Level Up detected during sync!');
          }
          success = true;
        } else {
          success = false;
        }
      } else {
        // Just pull latest profile if no offline transactions
        final profile = await syncUserProfile();
        if (profile != null) {
          await OfflineCache.saveCurrency(
            profile['dreamCoins'] ?? 0,
            profile['hellStones'] ?? 0,
            profile['playtime'] ?? 0,
            profile['freeSpins'] ?? 0,
            profile['xp'] ?? 0,
            profile['level'] ?? 1,
          );
          success = true;
        }
      }

      // 2. Sync Game Progress & Inventory (Optional items that require backend to handle)
      if (success) {
        final progress = await OfflineCache.getGameProgress();
        final inventory = await OfflineCache.getInventory();
        
        try {
          await post('/user/sync-progress', body: {
            'progress': progress,
            'inventory': inventory,
          }).timeout(const Duration(seconds: 15));
        } catch (e) {
          debugPrint('Progress sync failed (non-critical): $e');
        }
      }

      await OfflineCache.saveLastSync(success);
      return success;
    } catch (e) {
      debugPrint('Full sync failed: $e');
      await OfflineCache.saveLastSync(false);
      return false;
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

  /// Reconciles offline transactions with the backend
  Future<Map<String, dynamic>?> reconcileEconomy(List<Map<String, dynamic>> transactions) async {
    try {
      final response = await post(
        '/economy/reconcile',
        body: {'transactions': transactions},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error reconciling economy: $e');
      return null;
    }
  }

  /// Synchronizes local economy state with the backend (deprecated - use reconcile)
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

  /// Fetches the leaderboard data
  Future<List<dynamic>?> getLeaderboard(String criteria, {int limit = 10}) async {
    try {
      final response = await get('/leaderboard/top?by=$criteria&limit=$limit');
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

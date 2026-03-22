import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Note: We don't import backend_config.dart here as admin_app might have its own or we can just use strings
// but to be consistent with the task of modularizing, we should ideally share the config.
// For now, I will use local constants but keep the same structure as frontend.

class OfflineCache {
  static const String _statsKey = 'cached_stats_summary';
  static const String _settingsKey = 'app_settings';

  /// Helper to get a key scoped to the current user (admin)
  static String _getScopedKey(String baseKey) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest_admin';
    return '${uid}_$baseKey';
  }

  static Future<void> saveSettings(Map<String, bool> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, json.encode(settings));
  }

  static Future<Map<String, bool>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_settingsKey);
    if (cached != null) {
      final Map<String, dynamic> data = json.decode(cached);
      return {
        'notifications': data['notifications'] as bool? ?? true,
        'darkMode': data['darkMode'] as bool? ?? true,
      };
    }
    return {'notifications': true, 'darkMode': true};
  }

  static Future<void> saveStatsSummary(Map<String, dynamic> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getScopedKey(_statsKey), json.encode(stats));
  }

  static Future<Map<String, dynamic>?> getStatsSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_getScopedKey(_statsKey));
    if (cached != null) {
      return json.decode(cached) as Map<String, dynamic>;
    }
    return null;
  }

  /// Clears ALL admin-specific data from local storage.
  static Future<void> clearAllUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final keys = prefs.getKeys();
    final userPrefix = '${uid}_';

    for (final key in keys) {
      if (key.startsWith(userPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  static Future<void> saveMetadata(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getScopedKey(key), json.encode(data));
  }

  static Future<Map<String, dynamic>?> getMetadata(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_getScopedKey(key));
    if (cached != null) {
      return json.decode(cached) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> clearMetadata(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getScopedKey(key));
  }

  static Future<void> clearCache() async {
    await clearAllUserData();
  }
}

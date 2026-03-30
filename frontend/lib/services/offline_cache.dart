import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OfflineCache {
  static const String _currencyKey = 'currency_v1';
  static const String _settingsKey = 'settings_v1';

  static String _getScopedKey(String baseKey) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return '${uid}_$baseKey';
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, json.encode(settings));
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_settingsKey);
    if (cached != null) {
      return json.decode(cached) as Map<String, dynamic>;
    }
    return {'music': true, 'sfx': true, 'musicVolume': 0.79, 'sfxVolume': 1.0};
  }

  static Future<void> saveCurrency(int dreamCoins, int hellStones) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {'dreamCoins': dreamCoins, 'hellStones': hellStones};
    await prefs.setString(_getScopedKey(_currencyKey), json.encode(data));
  }

  static Future<Map<String, int>> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_getScopedKey(_currencyKey));
    if (cached != null) {
      final Map<String, dynamic> data = json.decode(cached);
      return {
        'dreamCoins': data['dreamCoins'] as int? ?? 500,
        'hellStones': data['hellStones'] as int? ?? 10,
      };
    }
    return {'dreamCoins': 500, 'hellStones': 10};
  }

  static Future<void> clearAllUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('${uid}_')) {
        await prefs.remove(key);
      }
    }
  }

  // Stubs for removed methods to prevent immediate build errors
  static Future<void> migrateGuestData(String uid) async {}
  static Future<List<dynamic>> getTransactionQueue() async => [];
  static Future<void> addTransaction({
    required String type,
    int dreamDelta = 0,
    int hellDelta = 0,
    int playtimeDelta = 0,
  }) async {}
  static Future<Map<String, dynamic>?> getDailyTasks() async => null;
  static Future<void> saveNotifiedTaskIds(Set<String> ids) async {}

  static Future<void> saveMetadata(
    String key,
    Map<String, dynamic> data,
  ) async {
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
}

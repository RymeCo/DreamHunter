import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OfflineCache {
  static const String _currencyKey = 'currency_v1';
  static const String _settingsKey = 'settings_v1';
  static SharedPreferences? _prefs;

  /// Pre-caches the SharedPreferences instance to avoid 500ms+ delays during I/O calls.
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    if (_prefs == null) {
      throw Exception(
        "OfflineCache not initialized. Call initialize() in main.",
      );
    }
    return _prefs!;
  }

  static String _getScopedKey(String baseKey) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return '${uid}_$baseKey';
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _p.setString(_settingsKey, json.encode(settings));
  }

  static Future<Map<String, dynamic>> getSettings() async {
    await initialize(); // Fallback just in case
    final cached = _p.getString(_settingsKey);
    if (cached != null) {
      return json.decode(cached) as Map<String, dynamic>;
    }
    return {'music': true, 'sfx': true, 'musicVolume': 0.79, 'sfxVolume': 1.0};
  }

  static Future<void> saveCurrency(int dreamCoins, int hellStones) async {
    final data = {'dreamCoins': dreamCoins, 'hellStones': hellStones};
    await _p.setString(_getScopedKey(_currencyKey), json.encode(data));
  }

  static Future<Map<String, int>> getCurrency() async {
    final cached = _p.getString(_getScopedKey(_currencyKey));
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final keys = _p.getKeys();
    for (final key in keys) {
      if (key.startsWith('${uid}_')) {
        await _p.remove(key);
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
    await _p.setString(_getScopedKey(key), json.encode(data));
  }

  static Future<Map<String, dynamic>?> getMetadata(String key) async {
    final cached = _p.getString(_getScopedKey(key));
    if (cached != null) {
      return json.decode(cached) as Map<String, dynamic>;
    }
    return null;
  }
}

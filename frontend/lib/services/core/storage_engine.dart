import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Minimalist Singleton to handle on-device data persistence.
class StorageEngine {
  static final StorageEngine instance = StorageEngine._internal();
  factory StorageEngine() => instance;
  StorageEngine._internal();

  static const String _currencyKey = 'currency_v1';
  static const String _settingsKey = 'settings_v1';
  static const String _pendingConflictKey = 'pending_save_conflict';
  static SharedPreferences? _prefs;

  /// Pre-caches the SharedPreferences instance.
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    if (_prefs == null) {
      throw Exception(
        "StorageEngine not initialized. Call initialize() in main.",
      );
    }
    return _prefs!;
  }

  String _getScopedKey(String baseKey) {
    String uid = 'guest';
    try {
      uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    } catch (e) {
      // Firebase not initialized yet, fallback to guest
    }
    return '${uid}_$baseKey';
  }

  // --- Device Global Settings ---
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _p.setString(_settingsKey, json.encode(settings));
  }

  Future<Map<String, dynamic>> getSettings() async {
    final cached = _p.getString(_settingsKey);
    if (cached != null) {
      try {
        return json.decode(cached) as Map<String, dynamic>;
      } catch (e) {
        return _defaultSettings();
      }
    }
    return _defaultSettings();
  }

  Map<String, dynamic> _defaultSettings() => {
    'music': true,
    'sfx': true,
    'musicVolume': 0.8,
    'sfxVolume': 1.0,
  };

  // --- Scoped User Data ---

  Future<void> saveCurrency(int dreamCoins, int hellStones) async {
    final data = {'dreamCoins': dreamCoins, 'hellStones': hellStones};
    await _p.setString(_getScopedKey(_currencyKey), json.encode(data));
  }

  Future<Map<String, int>> getCurrency() async {
    final cached = _p.getString(_getScopedKey(_currencyKey));
    if (cached != null) {
      try {
        final Map<String, dynamic> data = json.decode(cached);
        return {
          'dreamCoins': data['dreamCoins'] as int? ?? 500,
          'hellStones': data['hellStones'] as int? ?? 10,
        };
      } catch (e) {
        return {'dreamCoins': 500, 'hellStones': 10};
      }
    }
    return {'dreamCoins': 500, 'hellStones': 10};
  }

  Future<void> saveMetadata(String key, Map<String, dynamic> data) async {
    await _p.setString(_getScopedKey(key), json.encode(data));
  }

  Future<Map<String, dynamic>?> getMetadata(String key) async {
    final cached = _p.getString(_getScopedKey(key));
    if (cached != null) {
      try {
        return json.decode(cached) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // --- Global (Unscoped) Data ---

  Future<void> saveGlobalMetadata(String key, Map<String, dynamic> data) async {
    await _p.setString('global_$key', json.encode(data));
  }

  Future<Map<String, dynamic>?> getGlobalMetadata(String key) async {
    final cached = _p.getString('global_$key');
    if (cached != null) {
      try {
        return json.decode(cached) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // --- Daily Quota Tracking ---

  Future<int> getDailyCount(String key) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final stored = await getMetadata('daily_count_$key');
    if (stored != null && stored['date'] == today) {
      return stored['count'] as int;
    }
    return 0;
  }

  Future<void> incrementDailyCount(String key) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final current = await getDailyCount(key);
    await saveMetadata('daily_count_$key', {
      'date': today,
      'count': current + 1,
    });
  }

  // --- Save Management & Conflict Resolution ---

  /// Checks if there is any local progression for the 'guest' profile.
  bool hasGuestData() {
    final keys = _p.getKeys();
    return keys.any((k) => k.startsWith('guest_'));
  }

  /// Sets a flag indicating that a save conflict needs resolution.
  /// This is used to re-prompt the user if the app crashes during login.
  Future<void> setPendingConflict(bool pending) async {
    await _p.setBool(_pendingConflictKey, pending);
  }

  bool isConflictPending() {
    return _p.getBool(_pendingConflictKey) ?? false;
  }

  /// Copies 'guest_' data to '{targetUid}_' keys.
  /// This ARCHIVES the guest data (it is never deleted).
  Future<void> promoteGuestToUser(String targetUid) async {
    final keys = _p.getKeys();
    for (final key in keys) {
      if (key.startsWith('guest_')) {
        final value = _p.get(key);
        final newKey = key.replaceFirst('guest_', '${targetUid}_');

        if (value is String) {
          await _p.setString(newKey, value);
        } else if (value is bool) {
          await _p.setBool(newKey, value);
        } else if (value is int) {
          await _p.setInt(newKey, value);
        } else if (value is double) {
          await _p.setDouble(newKey, value);
        } else if (value is List<String>) {
          await _p.setStringList(newKey, value);
        }
      }
    }
  }

  Future<void> clearAllUserData() async {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}
    
    if (uid == null) return;
    
    // Clear the token cache specifically
    await clearCachedToken();

    final keys = _p.getKeys();
    for (final key in keys) {
      if (key.startsWith('${uid}_')) {
        await _p.remove(key);
      }
    }
  }

  // --- Token Caching (Speed Optimization) ---
  static const String _tokenCacheKey = 'cached_id_token';

  Future<void> saveCachedToken(String token) async {
    await _p.setString(_getScopedKey(_tokenCacheKey), token);
  }

  String? getCachedToken() {
    return _p.getString(_getScopedKey(_tokenCacheKey));
  }

  Future<void> clearCachedToken() async {
    await _p.remove(_getScopedKey(_tokenCacheKey));
  }
}

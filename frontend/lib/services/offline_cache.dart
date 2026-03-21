import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OfflineTransaction {
  final String id;
  final String type; // 'PURCHASE', 'CONVERSION', 'EARN', 'PLAYTIME', 'ROULETTE_SPIN', 'BUY_SPIN', 'ROULETTE_REWARD', 'IAP_PURCHASE'
  final String? itemId;
  final int dreamDelta;
  final int hellDelta;
  final int playtimeDelta; // In seconds
  final int freeSpinDelta; // For roulette spins
  final String timestamp;

  OfflineTransaction({
    required this.id,
    required this.type,
    this.itemId,
    this.dreamDelta = 0,
    this.hellDelta = 0,
    this.playtimeDelta = 0,
    this.freeSpinDelta = 0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'itemId': itemId,
    'dreamDelta': dreamDelta,
    'hellDelta': hellDelta,
    'playtimeDelta': playtimeDelta,
    'freeSpinDelta': freeSpinDelta,
    'timestamp': timestamp,
  };

  factory OfflineTransaction.fromJson(Map<String, dynamic> json) => OfflineTransaction(
    id: json['id'],
    type: json['type'],
    itemId: json['itemId'],
    dreamDelta: json['dreamDelta'] ?? 0,
    hellDelta: json['hellDelta'] ?? 0,
    playtimeDelta: json['playtimeDelta'] ?? 0,
    freeSpinDelta: json['freeSpinDelta'] ?? 0,
    timestamp: json['timestamp'],
  );
}

class OfflineCache {
  static const String _currencyKey = 'cached_currency';
  static const String _transactionQueueKey = 'transaction_queue';
  static const String _settingsKey = 'app_settings';
  static const String _inventoryKey = 'cached_inventory';
  static const String _progressKey = 'cached_progress';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _lastSyncStatusKey = 'last_sync_status';
  static const _uuid = Uuid();

  /// Helper to get a key scoped to the current user (or guest)
  static String _getScopedKey(String baseKey, [String? uid]) {
    final currentUid = uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return '${currentUid}_$baseKey';
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
        'music': data['music'] as bool? ?? true,
        'sfx': data['sfx'] as bool? ?? true,
      };
    }
    return {'music': true, 'sfx': true};
  }

  static Future<void> saveCurrency(int dreamCoins, int hellStones, [int playtime = 0, int freeSpins = 0]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getScopedKey(_currencyKey), json.encode({
      'dreamCoins': dreamCoins,
      'hellStones': hellStones,
      'playtime': playtime,
      'freeSpins': freeSpins,
    }));
  }

  static Future<Map<String, int>?> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_getScopedKey(_currencyKey));
    if (cached != null) {
      final Map<String, dynamic> data = json.decode(cached);
      return {
        'dreamCoins': data['dreamCoins'] as int,
        'hellStones': data['hellStones'] as int,
        'playtime': data['playtime'] as int? ?? 0,
        'freeSpins': data['freeSpins'] as int? ?? 0,
      };
    }
    return null;
  }

  static Future<void> addTransaction({
    required String type,
    String? itemId,
    int dreamDelta = 0,
    int hellDelta = 0,
    int playtimeDelta = 0,
    int freeSpinDelta = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getTransactionQueue();
    
    final transaction = OfflineTransaction(
      id: _uuid.v4(),
      type: type,
      itemId: itemId,
      dreamDelta: dreamDelta,
      hellDelta: hellDelta,
      playtimeDelta: playtimeDelta,
      freeSpinDelta: freeSpinDelta,
      timestamp: DateTime.now().toUtc().toIsoformat(),
    );
    
    queue.add(transaction);
    await prefs.setString(_getScopedKey(_transactionQueueKey), json.encode(queue.map((t) => t.toJson()).toList()));
    
    // Also update local currency/playtime immediately
    final current = await getCurrency() ?? {'dreamCoins': 0, 'hellStones': 0, 'playtime': 0, 'freeSpins': 0};
    await saveCurrency(
      current['dreamCoins']! + dreamDelta,
      current['hellStones']! + hellDelta,
      current['playtime']! + playtimeDelta,
      current['freeSpins']! + freeSpinDelta,
    );
  }

  static Future<List<OfflineTransaction>> getTransactionQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_getScopedKey(_transactionQueueKey));
    if (cached != null) {
      final List<dynamic> list = json.decode(cached);
      return list.map((item) => OfflineTransaction.fromJson(item)).toList();
    }
    return [];
  }

  static Future<void> clearTransactionQueue({List<String>? ids}) async {
    final prefs = await SharedPreferences.getInstance();
    if (ids == null) {
      await prefs.remove(_getScopedKey(_transactionQueueKey));
    } else {
      final queue = await getTransactionQueue();
      queue.removeWhere((t) => ids.contains(t.id));
      await prefs.setString(_getScopedKey(_transactionQueueKey), json.encode(queue.map((t) => t.toJson()).toList()));
    }
  }

  static Future<void> saveStatsSummary(String key, Map<String, dynamic> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getScopedKey(key), json.encode(stats));
  }

  static Future<void> saveInventory(List<String> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_getScopedKey(_inventoryKey), items);
  }

  static Future<List<String>> getInventory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_getScopedKey(_inventoryKey)) ?? [];
  }

  static Future<void> saveGameProgress(Map<String, dynamic> progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getScopedKey(_progressKey), json.encode(progress));
  }

  static Future<Map<String, dynamic>> getGameProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_getScopedKey(_progressKey));
    if (cached != null) {
      return json.decode(cached) as Map<String, dynamic>;
    }
    return {};
  }

  static Future<void> saveMetadata(String key, Map<String, dynamic> metadata) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('metadata_$key', json.encode(metadata));
  }

  static Future<Map<String, dynamic>?> getMetadata(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('metadata_$key');
    if (cached != null) {
      return json.decode(cached) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> clearMetadata(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('metadata_$key');
  }

  static Future<void> saveLastSync([bool success = true]) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setString(_getScopedKey(_lastSyncKey), now);
    await prefs.setBool(_getScopedKey(_lastSyncStatusKey), success);
  }

  static Future<Map<String, dynamic>> getLastSyncInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'timestamp': prefs.getString(_getScopedKey(_lastSyncKey)),
      'success': prefs.getBool(_getScopedKey(_lastSyncStatusKey)) ?? false,
    };
  }

  /// Migrates guest data to a new user UID. Used during login/registration.
  /// Note: Guest data is COPIED, not moved, to allow guest session restoration on logout.
  static Future<void> migrateGuestData(String newUid) async {
    final prefs = await SharedPreferences.getInstance();
    const guestUid = 'guest';

    final sensitiveKeys = [
      _currencyKey,
      _transactionQueueKey,
      _inventoryKey,
      _progressKey,
    ];

    for (final key in sensitiveKeys) {
      final guestKey = _getScopedKey(key, guestUid);
      final userKey = _getScopedKey(key, newUid);

      final guestData = prefs.getString(guestKey);
      final guestList = prefs.getStringList(guestKey);
      
      if (guestData != null) {
        if (key == _transactionQueueKey) {
          final List guestQueue = json.decode(guestData);
          final userQueueData = prefs.getString(userKey);
          final List userQueue = userQueueData != null ? json.decode(userQueueData) : [];
          
          // Only add transactions that aren't already in the user queue (by ID)
          final userIds = userQueue.map((t) => t['id'] as String).toSet();
          for (final t in guestQueue) {
            if (!userIds.contains(t['id'])) {
              userQueue.add(t);
            }
          }
          await prefs.setString(userKey, json.encode(userQueue));
          
          // Clear guest transaction queue so they aren't processed twice, 
          // but we KEEP guest currency/progress keys for restoration.
          await prefs.remove(guestKey);
        } else {
          // If user already has data, we don't overwrite it with guest data (cloud is truth)
          if (!prefs.containsKey(userKey)) {
             await prefs.setString(userKey, guestData);
          }
          // Do NOT remove guestKey here - we want to keep it for when they logout.
        }
      } else if (guestList != null) {
        if (!prefs.containsKey(userKey)) {
          await prefs.setStringList(userKey, guestList);
        }
        // Do NOT remove guestKey here
      }
    }
  }

  /// Clears ALL user-specific data from local storage.
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

  static Future<void> clearCache() async {
    await clearAllUserData();
  }
}


extension DateTimeIso on DateTime {
  String toIsoformat() => toIso8601String();
}

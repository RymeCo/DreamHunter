import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
  static const _uuid = Uuid();

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
    await prefs.setString(_currencyKey, json.encode({
      'dreamCoins': dreamCoins,
      'hellStones': hellStones,
      'playtime': playtime,
      'freeSpins': freeSpins,
    }));
  }

  static Future<Map<String, int>?> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_currencyKey);
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
    await prefs.setString(_transactionQueueKey, json.encode(queue.map((t) => t.toJson()).toList()));
    
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
    final cached = prefs.getString(_transactionQueueKey);
    if (cached != null) {
      final List<dynamic> list = json.decode(cached);
      return list.map((item) => OfflineTransaction.fromJson(item)).toList();
    }
    return [];
  }

  static Future<void> clearTransactionQueue({List<String>? ids}) async {
    final prefs = await SharedPreferences.getInstance();
    if (ids == null) {
      await prefs.remove(_transactionQueueKey);
    } else {
      final queue = await getTransactionQueue();
      queue.removeWhere((t) => ids.contains(t.id));
      await prefs.setString(_transactionQueueKey, json.encode(queue.map((t) => t.toJson()).toList()));
    }
  }

  static Future<void> saveStatsSummary(String key, Map<String, dynamic> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(stats));
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

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currencyKey);
    await prefs.remove(_transactionQueueKey);
  }
}

extension DateTimeIso on DateTime {
  String toIsoformat() => toIso8601String();
}

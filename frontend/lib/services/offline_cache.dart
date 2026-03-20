import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCache {
  static const String _currencyKey = 'cached_currency';

  static Future<void> saveCurrency(int dreamCoins, int hellStones) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, json.encode({
      'dreamCoins': dreamCoins,
      'hellStones': hellStones,
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
      };
    }
    return null;
  }

  static Future<void> saveStatsSummary(String key, Map<String, dynamic> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(stats));
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currencyKey);
  }
}

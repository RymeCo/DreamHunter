import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCache {
  static const String _statsKey = 'cached_stats_summary';

  static Future<void> saveStatsSummary(Map<String, dynamic> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, json.encode(stats));
  }

  static Future<Map<String, dynamic>?> getStatsSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_statsKey);
    if (cached != null) {
      return json.decode(cached) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsKey);
  }
}

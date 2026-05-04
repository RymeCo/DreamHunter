import 'package:flutter/foundation.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';

/// Minimalist Singleton to handle Player XP, Leveling, and Persistence.
class ProgressionManager extends ChangeNotifier {
  static final ProgressionManager instance = ProgressionManager._internal();
  factory ProgressionManager() => instance;
  ProgressionManager._internal();

  int _level = 1;
  int _xp = 0;
  bool _didLevelUpThisMatch = false;

  int get level => _level;
  int get xp => _xp;
  bool get didLevelUpThisMatch => _didLevelUpThisMatch;

  /// Required XP for the NEXT level.
  int get xpThreshold => _level * 500;

  /// Progress percentage towards next level (0.0 to 1.0).
  double get progress => (_xp / xpThreshold).clamp(0.0, 1.0);

  /// Initializes the manager from the latest cached player profile.
  Future<void> initialize() async {
    final cached = await StorageEngine.instance.getMetadata('player_profile');
    if (cached != null) {
      _level = cached['level'] ?? 1;
      _xp = cached['xp'] ?? 0;
      notifyListeners();
    }
  }

  /// Adds XP earned from a match and handles multiple level-ups.
  Future<void> addXp(int amount, {bool resetLevelUpFlag = false}) async {
    if (amount <= 0) return;

    if (resetLevelUpFlag) _didLevelUpThisMatch = false;
    _xp += amount;

    // Handle potential multi-level jumps
    while (_xp >= xpThreshold) {
      _xp -= xpThreshold;
      _level++;
      _didLevelUpThisMatch = true;
    }

    notifyListeners();
    await _persist();
  }

  /// Forces a reload from cache (called after cloud sync).
  Future<void> reloadFromCache() async => await initialize();

  Future<void> _persist() async {
    final cached = await StorageEngine.instance.getMetadata('player_profile');
    if (cached != null) {
      final updated = {
        ...cached,
        'level': _level,
        'xp': _xp,
      };
      await StorageEngine.instance.saveMetadata('player_profile', updated);
      
      // We don't call backupPlayer here to avoid spamming the backend;
      // ProfileManager will handle the full sync at natural intervals.
    }
  }
}

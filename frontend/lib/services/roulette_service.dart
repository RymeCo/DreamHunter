import 'dart:developer' as developer;
import 'offline_cache.dart';

class RouletteState {
  final int freeSpins;
  final String lastRefillDate; // YYYY-MM-DD
  final Map<String, dynamic>?
  pendingReward; // { 'amount': int, 'name': String }
  final bool isSpinning;
  final double? targetRotation;
  final String? spinStartTime; // ISO8601

  RouletteState({
    required this.freeSpins,
    required this.lastRefillDate,
    this.pendingReward,
    this.isSpinning = false,
    this.targetRotation,
    this.spinStartTime,
  });

  Map<String, dynamic> toJson() => {
    'freeSpins': freeSpins,
    'lastRefillDate': lastRefillDate,
    'pendingReward': pendingReward,
    'isSpinning': isSpinning,
    'targetRotation': targetRotation,
    'spinStartTime': spinStartTime,
  };

  factory RouletteState.fromJson(Map<String, dynamic> json) {
    return RouletteState(
      freeSpins: json['freeSpins'] as int? ?? 10,
      lastRefillDate: json['lastRefillDate'] as String? ?? '',
      pendingReward: json['pendingReward'] as Map<String, dynamic>?,
      isSpinning: json['isSpinning'] as bool? ?? false,
      targetRotation: (json['targetRotation'] as num?)?.toDouble(),
      spinStartTime: json['spinStartTime'] as String?,
    );
  }
}

class RouletteService {
  static const String _rouletteKey = 'roulette_state_v1';
  static const int maxFreeSpins = 10;

  static const List<Map<String, dynamic>> rewards = [
    {
      'name': '10 DC',
      'type': 'currency',
      'amount': 10,
      'weight': 100, // Common
      'color': '0xCC9C27B0', // Deep Purple
    },
    {
      'name': '25 DC',
      'type': 'currency',
      'amount': 25,
      'weight': 50, // Uncommon
      'color': '0xCC2196F3', // Blue
    },
    {
      'name': '50 DC',
      'type': 'currency',
      'amount': 50,
      'weight': 20, // Rare
      'color': '0xCC00BCD4', // Cyan
    },
    {
      'name': '100 DC',
      'type': 'currency',
      'amount': 100,
      'weight': 10, // Epic
      'color': '0xCCFFD740', // Amber
    },
    {
      'name': '250 DC',
      'type': 'currency',
      'amount': 250,
      'weight': 5, // Legendary
      'color': '0xCCFF4081', // Pink
    },
    {
      'name': '500 DC',
      'type': 'currency',
      'amount': 500,
      'weight': 2, // Jackpot
      'color': '0xCCFF5252', // Red Accent
    },
  ];

  /// Loads the current state and applies daily refill logic.
  static Future<RouletteState> getAndSyncState() async {
    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    Map<String, dynamic>? data = await OfflineCache.getMetadata(_rouletteKey);
    RouletteState state = data != null
        ? RouletteState.fromJson(data)
        : RouletteState(freeSpins: 10, lastRefillDate: todayStr);

    // 1. Daily Refill Logic: Add +1 spin if it's a new day and we are under the limit
    if (state.lastRefillDate != todayStr) {
      int newSpins = state.freeSpins;
      if (newSpins < maxFreeSpins) {
        newSpins++;
        developer.log(
          'Daily refill: +1 free spin granted.',
          name: 'RouletteService',
        );
      }

      state = RouletteState(
        freeSpins: newSpins,
        lastRefillDate: todayStr,
        pendingReward: state.pendingReward,
        isSpinning: state.isSpinning,
        targetRotation: state.targetRotation,
        spinStartTime: state.spinStartTime,
      );
      await saveState(state);
    }

    return state;
  }

  static Future<void> setSpinning(
    bool isSpinning, {
    double? targetRotation,
  }) async {
    final state = await getAndSyncState();
    final newState = RouletteState(
      freeSpins: state.freeSpins,
      lastRefillDate: state.lastRefillDate,
      pendingReward: state.pendingReward,
      isSpinning: isSpinning,
      targetRotation: targetRotation,
      spinStartTime: isSpinning ? DateTime.now().toIso8601String() : null,
    );
    await saveState(newState);
  }

  static Future<void> setPendingReward(Map<String, dynamic> reward) async {
    final state = await getAndSyncState();
    final newState = RouletteState(
      freeSpins: state.freeSpins,
      lastRefillDate: state.lastRefillDate,
      pendingReward: reward,
    );
    await saveState(newState);
  }

  static Future<void> clearPendingReward() async {
    final state = await getAndSyncState();
    final newState = RouletteState(
      freeSpins: state.freeSpins,
      lastRefillDate: state.lastRefillDate,
      pendingReward: null,
    );
    await saveState(newState);
  }

  static Future<void> saveState(RouletteState state) async {
    await OfflineCache.saveMetadata(_rouletteKey, state.toJson());
  }

  /// Consumes one free spin if available. Returns true if successful.
  static Future<bool> consumeFreeSpin() async {
    final state = await getAndSyncState();
    if (state.freeSpins > 0) {
      final newState = RouletteState(
        freeSpins: state.freeSpins - 1,
        lastRefillDate: state.lastRefillDate,
      );
      await saveState(newState);
      return true;
    }
    return false;
  }

  /// Refills spins to max capacity (10/10).
  static Future<void> refillToMax() async {
    final state = await getAndSyncState();
    final newState = RouletteState(
      freeSpins: maxFreeSpins,
      lastRefillDate: state.lastRefillDate,
    );
    await saveState(newState);
    developer.log('Spins refilled to max.', name: 'RouletteService');
  }
}

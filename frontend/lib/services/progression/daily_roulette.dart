import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dreamhunter/models/task_model.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';
import 'package:dreamhunter/services/progression/task_service.dart';

class RouletteState {
  final int freeSpins;
  final String lastRefillDate; // YYYY-MM-DD
  final bool isSpinning;
  final bool lastSpinWasPaid; // Used for refunds if crashed
  final double? targetRotation;
  final String? spinStartTime;

  RouletteState({
    required this.freeSpins,
    required this.lastRefillDate,
    this.isSpinning = false,
    this.lastSpinWasPaid = false,
    this.targetRotation,
    this.spinStartTime,
  });

  Map<String, dynamic> toJson() => {
    'freeSpins': freeSpins,
    'lastRefillDate': lastRefillDate,
    'isSpinning': isSpinning,
    'lastSpinWasPaid': lastSpinWasPaid,
    'targetRotation': targetRotation,
    'spinStartTime': spinStartTime,
  };

  factory RouletteState.fromJson(Map<String, dynamic> json) {
    return RouletteState(
      freeSpins: json['freeSpins'] as int? ?? 10,
      lastRefillDate: json['lastRefillDate'] as String? ?? '',
      isSpinning: json['isSpinning'] as bool? ?? false,
      lastSpinWasPaid: json['lastSpinWasPaid'] as bool? ?? false,
      targetRotation: (json['targetRotation'] as num?)?.toDouble(),
      spinStartTime: json['spinStartTime'] as String?,
    );
  }
}

/// Minimalist Singleton to handle Roulette state and rewards.
class DailyRoulette extends ChangeNotifier {
  static final DailyRoulette instance = DailyRoulette._internal();
  factory DailyRoulette() => instance;
  DailyRoulette._internal();

  static const String _rouletteKey = 'roulette_state_v1';
  static const int maxFreeSpins = 10;
  static const int paidSpinCost = 50;

  bool _isInitialized = false;
  RouletteState? _state;
  RouletteState get state =>
      _state ?? RouletteState(freeSpins: 10, lastRefillDate: '');

  static const List<Map<String, dynamic>> rewards = [
    {'name': '10 DC', 'amount': 10, 'weight': 100, 'color': '0xCC9C27B0'},
    {'name': '25 DC', 'amount': 25, 'weight': 50, 'color': '0xCC2196F3'},
    {'name': '50 DC', 'amount': 50, 'weight': 20, 'color': '0xCC00BCD4'},
    {'name': '100 DC', 'amount': 100, 'weight': 10, 'color': '0xCCFFD740'},
    {'name': '250 DC', 'amount': 250, 'weight': 5, 'color': '0xCCFF4081'},
    {'name': '500 DC', 'amount': 500, 'weight': 2, 'color': '0xCCFF5252'},
  ];

  Future<void> initialize({bool force = false}) async {
    if (_isInitialized && !force) return;

    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final data = await StorageEngine.instance.getMetadata(_rouletteKey);
    _state = data != null ? RouletteState.fromJson(data) : null;

    if (_state != null && _state!.lastRefillDate != todayStr) {
      int newSpins = (state.freeSpins < maxFreeSpins)
          ? state.freeSpins + 1
          : state.freeSpins;
      _state = RouletteState(freeSpins: newSpins, lastRefillDate: todayStr);
      await _persist();
    } else if (_state == null) {
      _state = RouletteState(freeSpins: maxFreeSpins, lastRefillDate: todayStr);
      await _persist();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Reloads state from cache (e.g. after logout/login).
  Future<void> reloadFromCache() async => await initialize(force: true);

  Future<void> setSpinning(
    bool isSpinning, {
    bool isPaid = false,
    double? targetRotation,
  }) async {
    if (isSpinning) {
      TaskService.instance.trackAction(TaskType.spin);
    }

    _state = RouletteState(
      freeSpins: state.freeSpins,
      lastRefillDate: state.lastRefillDate,
      isSpinning: isSpinning,
      lastSpinWasPaid: isPaid,
      targetRotation: targetRotation,
      spinStartTime: isSpinning ? DateTime.now().toIso8601String() : null,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> addFreeSpins(int amount) async {
    _state = RouletteState(
      freeSpins: (state.freeSpins + amount).clamp(0, maxFreeSpins),
      lastRefillDate: state.lastRefillDate,
      isSpinning: state.isSpinning,
      lastSpinWasPaid: state.lastSpinWasPaid,
      targetRotation: state.targetRotation,
      spinStartTime: state.spinStartTime,
    );
    await _persist();
    notifyListeners();
  }

  Future<bool> consumeFreeSpin() async {
    if (state.freeSpins > 0) {
      _state = RouletteState(
        freeSpins: state.freeSpins - 1,
        lastRefillDate: state.lastRefillDate,
        targetRotation: state.targetRotation,
        spinStartTime: state.spinStartTime,
      );
      await _persist();
      notifyListeners();
      return true;
    }
    return false;
  }

  Map<String, dynamic> getRandomReward() {
    final totalWeight = rewards.fold<int>(
      0,
      (sum, item) => sum + (item['weight'] as int),
    );
    int random = math.Random().nextInt(totalWeight);
    for (var reward in rewards) {
      random -= reward['weight'] as int;
      if (random < 0) return reward;
    }
    return rewards.first;
  }

  Future<void> _persist() async =>
      await StorageEngine.instance.saveMetadata(_rouletteKey, state.toJson());
}

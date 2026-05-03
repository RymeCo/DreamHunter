import 'package:flame/extensions.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:dreamhunter/services/economy/wallet_manager.dart';

/// A Singleton state manager for the current match.
/// Acting as the "Single Source of Truth" for game state like paused status and in-match economy.
class MatchManager extends ChangeNotifier {
  static final MatchManager instance = MatchManager._internal();
  MatchManager._internal();

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  bool _isGameWon = false;
  bool get isGameWon => _isGameWon;

  bool _isHunterSleeping = false;
  bool get isHunterSleeping => _isHunterSleeping;

  String _currentRoomID = '';
  String get currentRoomID => _currentRoomID;

  // In-match Economy
  int _matchCoins = 0;
  int _matchEnergy = 0;

  int get matchCoins => _matchCoins;
  int get matchEnergy => _matchEnergy;

  // Tick System
  double _coinTickAccumulator = 0.0;
  double _energyTickAccumulator = 0.0;
  int _coinTickCount = 0;
  int _energyTickCount = 0;
  int _incomePerTick = 1;
  int _energyIncomePerTick = 0;

  int get coinTickCount => _coinTickCount;
  int get energyTickCount => _energyTickCount;

  // Legacy getter for backward compatibility
  int get tickCount => _coinTickCount;

  int get incomePerTick => _incomePerTick;
  int get energyIncomePerTick => _energyIncomePerTick;

  // AI Hunters
  final List<String> _aiSkins = [];
  List<String> get aiSkins => _aiSkins;

  // Attack Tracking (Index -> Remaining Pulse Duration)
  final Map<int, double> _attackTimers = {};
  Map<int, double> get attackTimers => _attackTimers;

  // Reward Tracking
  double _survivalTime = 0.0;
  double _damageDealt = 0.0;
  bool _playerKilledMonster = false;
  bool _matchEnded = false;
  bool _rewardsPersisted = false;
  bool _isForfeited = false;

  double get survivalTime => _survivalTime;
  double get damageDealt => _damageDealt;
  bool get playerKilledMonster => _playerKilledMonster;
  bool get matchEnded => _matchEnded;
  bool get isForfeited => _isForfeited;

  // Life Status (Index 0 = Player, 1+ = AI)
  final List<bool> _hunterAliveStatus = [true];
  List<bool> get hunterAliveStatus => List.unmodifiable(_hunterAliveStatus);

  /// Centralized Target Registry for Monster AI (Key: Target ID/Room ID)
  /// Tracks the "value" of a target to help the monster make strategic decisions.
  final Map<String, _TargetValue> _targetRegistry = {};

  /// Registers or updates a target's strategic value.
  void updateTargetValue({
    required String id,
    Vector2? position,
    int? entityLevel,
    bool? isOccupied,
    bool? isPlayer,
    double? hpPercent,
  }) {
    final entry = _targetRegistry.putIfAbsent(id, () => _TargetValue(id: id));
    if (position != null) entry.position = position;
    if (entityLevel != null) entry.level = entityLevel;
    if (isOccupied != null) entry.isOccupied = isOccupied;
    if (isPlayer != null) entry.isPlayer = isPlayer;
    if (hpPercent != null) entry.hpPercent = hpPercent;
  }

  /// Gets all registered targets sorted by strategic "attractiveness" (High-Score First).
  /// [monsterPos] allows factoring in distance to avoid kiting and prioritize proximity.
  List<String> getBestTargets(Vector2 monsterPos) {
    final list = _targetRegistry.values.toList();
    if (list.isEmpty) return [];

    // UNIFIED SCORING STRATEGY:
    // BaseScore = (Occupied ? 100 : 0) + (isPlayer ? 50 : 0)
    // DistancePenalty = Distance / 20
    // LevelPenalty = Level * 5
    // FinalScore = BaseScore - DistancePenalty - LevelPenalty
    
    list.sort((a, b) {
      final aScore = _calculateTargetScore(a, monsterPos);
      final bScore = _calculateTargetScore(b, monsterPos);
      return bScore.compareTo(aScore); // High score first
    });

    return list.map((e) => e.id).toList();
  }

  double _calculateTargetScore(_TargetValue target, Vector2 monsterPos) {
    double score = 0;
    
    // 1. Occupancy is the highest priority
    if (target.isOccupied) score += 100;
    if (target.isPlayer) score += 50;

    // 2. Distance Penalty (Closer is better)
    if (target.position != null) {
      final dist = monsterPos.distanceTo(target.position!);
      score -= (dist / 16.0); // 1 point per half-tile distance
    }

    // 3. Level Penalty (Lower level is easier to break)
    score -= (target.level * 5.0);

    // 4. HP Bonus (Finishing off targets)
    score += (1.0 - target.hpPercent) * 20.0;

    return score;
  }

  /// Resets match state for a fresh start.
  void resetMatch() {
    _isPaused = false;
    _isGameWon = false;
    _isHunterSleeping = false;
    _currentRoomID = '';
    _matchCoins = 0;
    _matchEnergy = 0;
    _coinTickCount = 0;
    _energyTickCount = 0;
    _coinTickAccumulator = 0.0;
    _energyTickAccumulator = 0.0;
    _incomePerTick = 1;
    _energyIncomePerTick = 0;
    _attackTimers.clear();
    _targetRegistry.clear();

    // Reset reward tracking
    _survivalTime = 0.0;
    _damageDealt = 0.0;
    _playerKilledMonster = false;
    _matchEnded = false;
    _rewardsPersisted = false;
    _isForfeited = false;

    _hunterAliveStatus.clear();
    _hunterAliveStatus.add(true); // Player
    for (int i = 0; i < _aiSkins.length; i++) {
      _hunterAliveStatus.add(true);
    }

    notifyListeners();
  }

  /// Ends the match in a win.
  void winMatch() {
    if (_isGameWon) return;
    _isGameWon = true;
    _isPaused = true;
    _matchEnded = true;
    persistRewards();
    _safeNotify(notifyListeners);
  }

  /// Persists the earned rewards to the global wallet.
  Future<void> persistRewards() async {
    if (_rewardsPersisted) return;
    _rewardsPersisted = true;

    final total = calculateRewards();
    if (total > 0) {
      await WalletManager.instance.updateBalance(coinsDelta: total);
    }
  }

  /// Sets the list of AI skins joining the match
  void setAISkins(List<String> skins) {
    _aiSkins.clear();
    _aiSkins.addAll(skins);

    // Initialize alive status for AI
    _hunterAliveStatus.clear();
    _hunterAliveStatus.add(true); // Player
    for (int i = 0; i < skins.length; i++) {
      _hunterAliveStatus.add(true);
    }
  }

  /// Marks a hunter as killed.
  void killHunter(int index) {
    if (index >= 0 && index < _hunterAliveStatus.length) {
      _hunterAliveStatus[index] = false;
      _attackTimers.remove(index);
      _safeNotify(notifyListeners);

      // If player died, mark match as ended
      if (index == 0) {
        _matchEnded = true;
        persistRewards();
      }
    }
  }

  /// Adds damage dealt by the player to the reward counter.
  void addPlayerDamage(double damage) {
    if (_matchEnded) return;
    _damageDealt += damage;
  }

  /// Records that the player dealt the final blow.
  void setPlayerKilledMonster() {
    if (_matchEnded) return;
    _playerKilledMonster = true;
    _matchEnded = true;
  }

  /// Calculates the reward based on performance.
  /// Hard cap at 50 coins.
  int calculateRewards() {
    if (_isForfeited) return 0;

    // ⏱️ Survival: 1 Coin per 15 seconds survived (Max 20 Coins / 5 Minutes)
    final survivalReward = (_survivalTime / 15.0).floor().clamp(0, 20);

    // ⚔️ Damage: 1 Coin per 50 damage (Max 20 Coins / 1000 Damage)
    final damageReward = (_damageDealt / 50.0).floor().clamp(0, 20);

    // 🎯 Kill Bonus: 10 Coins
    final killBonus = _playerKilledMonster ? 10 : 0;

    final total = (survivalReward + damageReward + killBonus).clamp(0, 50);
    return total;
  }

  /// Checks if a hunter is currently alive.
  bool isHunterAlive(int index) {
    if (index < 0 || index >= _hunterAliveStatus.length) return false;
    return _hunterAliveStatus[index];
  }

  /// Marks a hunter as under attack for a duration.
  void setHunterUnderAttack(int index, {double duration = 1.0}) {
    if (index >= 0 && index < _hunterAliveStatus.length) {
      if (!_hunterAliveStatus[index]) return;
      _attackTimers[index] = duration;
      _safeNotify(notifyListeners);
    }
  }

  /// Progresses the match logic based on delta time.
  /// Called by the Flame game loop.
  void update(double dt) {
    if (_isPaused) return;

    // Track survival time
    _survivalTime += dt;

    _coinTickAccumulator += dt;
    _energyTickAccumulator += dt;

    bool shouldNotify = false;

    // Update attack timers
    if (_attackTimers.isNotEmpty) {
      final keysToRemove = <int>[];
      for (final key in _attackTimers.keys) {
        final newVal = _attackTimers[key]! - dt;
        if (newVal <= 0) {
          keysToRemove.add(key);
        } else {
          _attackTimers[key] = newVal;
        }
      }

      if (keysToRemove.isNotEmpty) {
        for (final key in keysToRemove) {
          _attackTimers.remove(key);
        }
        shouldNotify = true;
      }
    }

    // Trigger Coin Logic Tick every 1.0s
    if (_coinTickAccumulator >= 1.0) {
      _coinTickAccumulator -= 1.0;
      _coinTickCount++;
      shouldNotify = true;
    }

    // Trigger Energy Logic Tick every 2.0s
    if (_energyTickAccumulator >= 2.0) {
      _energyTickAccumulator -= 2.0;
      _energyTickCount++;
      shouldNotify = true;
    }

    if (shouldNotify) {
      _safeNotify(notifyListeners);
    }
  }

  /// Synchronizes the global player wallet values (used for HUD)
  /// with the local PlayerEntity wallet.
  void syncPlayerWallet(int coins, int energy) {
    _matchCoins = coins;
    _matchEnergy = energy;
    _safeNotify(notifyListeners);
  }

  /// Safely triggers a callback that might notify listeners.
  /// If called during the build phase, it defers the execution to the post-frame callback.
  void _safeNotify(VoidCallback callback) {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        callback();
      });
    } else {
      callback();
    }
  }

  void setHunterSleeping(bool sleeping) {
    _isHunterSleeping = sleeping;
    _safeNotify(notifyListeners);
  }

  void setCurrentRoom(String roomID) {
    _currentRoomID = roomID;
    _safeNotify(notifyListeners);
  }

  void setIncomePerTick(int value) {
    _incomePerTick = value;
    _safeNotify(notifyListeners);
  }

  void setEnergyIncomePerTick(int value) {
    if (_energyIncomePerTick == value) return;
    _energyIncomePerTick = value.clamp(0, 100000);
    _safeNotify(notifyListeners);
  }

  void updateEnergyIncomePerTick(int delta) {
    _energyIncomePerTick = (_energyIncomePerTick + delta).clamp(0, 100000);
    _safeNotify(notifyListeners);
  }

  void updateMatchCoins(int delta) {
    _matchCoins = (_matchCoins + delta).clamp(0, 999999);
    notifyListeners();
  }

  /// Attempts to spend match coins. Returns true if successful.
  bool spendMatchCoins(int amount) {
    if (_matchCoins >= amount) {
      _matchCoins -= amount;
      _safeNotify(notifyListeners);
      return true;
    }
    return false;
  }

  /// Attempts to spend match energy. Returns true if successful.
  bool spendMatchEnergy(int amount) {
    if (_matchEnergy >= amount) {
      _matchEnergy -= amount;
      _safeNotify(notifyListeners);
      return true;
    }
    return false;
  }

  /// Attempts to spend both coins and energy. Returns true if successful.
  bool spendResources({int coins = 0, int energy = 0}) {
    if (_matchCoins >= coins && _matchEnergy >= energy) {
      _matchCoins -= coins;
      _matchEnergy -= energy;
      _safeNotify(notifyListeners);
      return true;
    }
    return false;
  }

  void updateMatchEnergy(int delta) {
    _matchEnergy = (_matchEnergy + delta).clamp(0, 100000);
    notifyListeners();
  }

  /// Pauses the game engine and any related timers.
  void pauseGame() {
    if (_isPaused) return;
    _isPaused = true;
    _safeNotify(notifyListeners);
  }

  /// Resumes the game engine and any related timers.
  void resumeGame() {
    if (!_isPaused) return;
    _isPaused = false;
    _safeNotify(notifyListeners);
  }

  /// Toggles the paused state.
  void togglePause() {
    _isPaused = !_isPaused;
    _safeNotify(notifyListeners);
  }

  void setForfeited() {
    _isForfeited = true;
    _matchEnded = true;
    _isPaused = true;
    _safeNotify(notifyListeners);
  }
}

class _TargetValue {
  final String id;
  Vector2? position;
  int level = 0;
  bool isOccupied = false;
  bool isPlayer = false;
  double hpPercent = 1.0;

  _TargetValue({required this.id});
}

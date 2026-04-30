import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

/// A Singleton state manager for the current match.
/// Acting as the "Single Source of Truth" for game state like paused status and in-match economy.
class MatchManager extends ChangeNotifier {
  static final MatchManager instance = MatchManager._internal();
  MatchManager._internal();

  bool _isPaused = false;
  bool get isPaused => _isPaused;

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

  // Life Status (Index 0 = Player, 1+ = AI)
  final List<bool> _hunterAliveStatus = [true];
  List<bool> get hunterAliveStatus => List.unmodifiable(_hunterAliveStatus);

  /// Resets match state for a fresh start.
  void resetMatch() {
    _isPaused = false;
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

    _hunterAliveStatus.clear();
    _hunterAliveStatus.add(true); // Reset player to alive

    notifyListeners();
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
      _safeNotify(notifyListeners);
    }
  }

  /// Progresses the match logic based on delta time.
  /// Called by the Flame game loop.
  void update(double dt) {
    if (_isPaused) return;

    _coinTickAccumulator += dt;
    _energyTickAccumulator += dt;

    bool shouldNotify = false;

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

  void updateEnergyIncomePerTick(int delta) {
    _energyIncomePerTick = (_energyIncomePerTick + delta).clamp(0, 100000);
    _safeNotify(notifyListeners);
  }

  // Legacy timer methods removed for logic integrity
  void stopTickSystem() {}

  void updateMatchCoins(int delta) {
    final oldBalance = _matchCoins;
    _matchCoins = (_matchCoins + delta).clamp(0, 999999);
    debugPrint('[ECONOMY] COINS: $oldBalance -> $_matchCoins (Change: $delta)');
    notifyListeners();
  }

  /// Attempts to spend match coins. Returns true if successful.
  bool spendMatchCoins(int amount) {
    if (_matchCoins >= amount) {
      final oldBalance = _matchCoins;
      _matchCoins -= amount;
      debugPrint(
        '[ECONOMY] SPEND COINS: $oldBalance -> $_matchCoins (Amount: $amount)',
      );
      _safeNotify(notifyListeners);
      return true;
    }
    debugPrint(
      '[ECONOMY] FAILED SPEND COINS: Balance $_matchCoins < Need $amount',
    );
    return false;
  }

  /// Attempts to spend match energy. Returns true if successful.
  bool spendMatchEnergy(int amount) {
    if (_matchEnergy >= amount) {
      final oldBalance = _matchEnergy;
      _matchEnergy -= amount;
      debugPrint(
        '[ECONOMY] SPEND ENERGY: $oldBalance -> $_matchEnergy (Amount: $amount)',
      );
      _safeNotify(notifyListeners);
      return true;
    }
    debugPrint(
      '[ECONOMY] FAILED SPEND ENERGY: Balance $_matchEnergy < Need $amount',
    );
    return false;
  }

  /// Attempts to spend both coins and energy. Returns true if successful.
  bool spendResources({int coins = 0, int energy = 0}) {
    if (_matchCoins >= coins && _matchEnergy >= energy) {
      final oldCoins = _matchCoins;
      final oldEnergy = _matchEnergy;
      _matchCoins -= coins;
      _matchEnergy -= energy;
      debugPrint(
        '[ECONOMY] SPEND MULTI: Coins $oldCoins->$_matchCoins, Energy $oldEnergy->$_matchEnergy',
      );
      _safeNotify(notifyListeners);
      return true;
    }
    debugPrint(
      '[ECONOMY] FAILED MULTI SPEND: Need ($coins C, $energy E) | Have ($_matchCoins C, $_matchEnergy E)',
    );
    return false;
  }

  void updateMatchEnergy(int delta) {
    final oldBalance = _matchEnergy;
    _matchEnergy = (_matchEnergy + delta).clamp(0, 100000);
    debugPrint(
      '[ECONOMY] ENERGY: $oldBalance -> $_matchEnergy (Change: $delta)',
    );
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
}

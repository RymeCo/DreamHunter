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
  double _tickAccumulator = 0.0;
  int _tickCount = 0;
  int _incomePerTick = 1;
  int _energyIncomePerTick = 0;

  int get tickCount => _tickCount;
  int get incomePerTick => _incomePerTick;
  int get energyIncomePerTick => _energyIncomePerTick;

  // AI Hunters
  final List<String> _aiSkins = [];
  List<String> get aiSkins => _aiSkins;

  /// Resets match state for a fresh start.
  void resetMatch() {
    _isPaused = false;
    _isHunterSleeping = false;
    _currentRoomID = '';
    _matchCoins = 0;
    _matchEnergy = 0;
    _tickCount = 0;
    _tickAccumulator = 0.0;
    _incomePerTick = 1;
    _energyIncomePerTick = 0;

    notifyListeners();
  }

  /// Sets the list of AI skins joining the match
  void setAISkins(List<String> skins) {
    _aiSkins.clear();
    _aiSkins.addAll(skins);
  }

  /// Progresses the match logic based on delta time.
  /// Called by the Flame game loop.
  void update(double dt) {
    if (_isPaused) return;

    _tickAccumulator += dt;

    // Trigger a logic tick every 1.0s (as per user request: 1tick/1second)
    if (_tickAccumulator >= 1.0) {
      _tickAccumulator -= 1.0;
      _tickCount++;

      // Resource generation - Safely defer notification to end of frame
      // to avoid "setState() called during build" errors from the Flame loop.
      _safeNotify(() {
        _matchCoins = (_matchCoins + _incomePerTick).clamp(0, 999999);
        _matchEnergy = (_matchEnergy + _energyIncomePerTick).clamp(0, 9999);
        notifyListeners();
      });
    }
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
    _energyIncomePerTick = (_energyIncomePerTick + delta).clamp(0, 9999);
    _safeNotify(notifyListeners);
  }

  // Legacy timer methods removed for logic integrity
  void stopTickSystem() {}

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
    _matchEnergy = (_matchEnergy + delta).clamp(0, 999);
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

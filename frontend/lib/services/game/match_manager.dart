import 'dart:async';
import 'package:flutter/foundation.dart';

/// A Singleton state manager for the current match.
/// Acting as the "Single Source of Truth" for game state like paused status and in-match economy.
class MatchManager extends ChangeNotifier {
  static final MatchManager instance = MatchManager._internal();
  MatchManager._internal();

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  // In-match Economy
  int _matchCoins = 0;
  int _matchEnergy = 0;
  
  int get matchCoins => _matchCoins;
  int get matchEnergy => _matchEnergy;

  // Tick System
  Timer? _tickTimer;
  int _tickCount = 0;
  int get tickCount => _tickCount;

  /// Resets match state for a fresh start and begins the tick system.
  void resetMatch() {
    _isPaused = false;
    _matchCoins = 0;
    _matchEnergy = 0;
    _tickCount = 0;
    
    _startTickSystem();
    notifyListeners();
  }

  void _startTickSystem() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isPaused) {
        _tickCount++;
        // Character earns +1 per tick (Passive Income)
        updateMatchCoins(1);
        // Note: updateMatchCoins already calls notifyListeners()
      }
    });
  }

  void stopTickSystem() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void updateMatchCoins(int delta) {
    _matchCoins = (_matchCoins + delta).clamp(0, 999999);
    notifyListeners();
  }

  void updateMatchEnergy(int delta) {
    _matchEnergy = (_matchEnergy + delta).clamp(0, 999);
    notifyListeners();
  }

  /// Pauses the game engine and any related timers.
  void pauseGame() {
    if (_isPaused) return;
    _isPaused = true;
    notifyListeners();
  }

  /// Resumes the game engine and any related timers.
  void resumeGame() {
    if (!_isPaused) return;
    _isPaused = false;
    notifyListeners();
  }

  /// Toggles the paused state.
  void togglePause() {
    _isPaused = !_isPaused;
    notifyListeners();
  }
}

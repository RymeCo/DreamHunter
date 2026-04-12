import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

enum GameStatus { playing, paused, gameOver, victory }

/// Manages the reactive state of the game, bridging Flame and Flutter.
class GameStateManager extends ChangeNotifier {
  double _matchTimeRemaining;
  final double _maxDuration;
  GameStatus _status = GameStatus.playing;

  GameStateManager({required double duration})
      : _matchTimeRemaining = duration,
        _maxDuration = duration;

  double get matchTimeRemaining => _matchTimeRemaining;
  double get progress => (_maxDuration - _matchTimeRemaining) / _maxDuration;
  GameStatus get status => _status;

  String get formattedTime {
    final minutes = (_matchTimeRemaining / 60).floor();
    final seconds = (_matchTimeRemaining % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void updateTimer(double dt) {
    if (_status != GameStatus.playing) return;

    _matchTimeRemaining -= dt;
    if (_matchTimeRemaining <= 0) {
      _matchTimeRemaining = 0;
      setGameOver(victory: true); // Survival victory
    }
    _safeNotifyListeners();
  }

  void setGameOver({required bool victory}) {
    if (_status == GameStatus.gameOver || _status == GameStatus.victory) return;
    _status = victory ? GameStatus.victory : GameStatus.gameOver;
    _safeNotifyListeners();
  }

  void pause() {
    _status = GameStatus.paused;
    _safeNotifyListeners();
  }

  void resume() {
    _status = GameStatus.playing;
    _safeNotifyListeners();
  }

  /// Ensures that listeners are notified after the build phase if necessary.
  void _safeNotifyListeners() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}


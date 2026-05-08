import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';

/// A singleton to track game performance and handle recovery.
class PerformanceManager extends ChangeNotifier {
  static final PerformanceManager instance = PerformanceManager._internal();
  PerformanceManager._internal();

  double _currentFPS = 60.0;
  double get currentFPS => _currentFPS;

  bool _isLagging = false;
  bool get isLagging => _isLagging;

  double _lowFPSDuration = 0.0;
  static const double lagThreshold = 25.0; // FPS below this is "laggy"
  static const double sustainedDuration =
      5.0; // Seconds of lag before notification

  void updateFPS(double dt) {
    if (dt <= 0) return;

    // Smooth the FPS reading (Exponential Moving Average)
    final instantFPS = 1.0 / dt;
    _currentFPS = _currentFPS * 0.9 + instantFPS * 0.1;

    if (_currentFPS < lagThreshold) {
      _lowFPSDuration += dt;
      if (_lowFPSDuration >= sustainedDuration && !_isLagging) {
        _isLagging = true;
        notifyListeners();
        AudioManager.instance
            .playClick(); // Use click instead of non-existent error sound
      }
    } else {
      // Recovery logic: Needs a bit of "good" performance to reset the warning
      if (_lowFPSDuration > 0) {
        _lowFPSDuration -= dt * 2; // Recover twice as fast as it drops
        if (_lowFPSDuration <= 0 && _isLagging) {
          _isLagging = false;
          _lowFPSDuration = 0;
          notifyListeners();
        }
      }
    }
  }

  void resetLagWarning() {
    _isLagging = false;
    _lowFPSDuration = 0;
    notifyListeners();
  }
}

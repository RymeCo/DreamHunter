import 'package:flutter/services.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';

class HapticManager {
  static final HapticManager instance = HapticManager._internal();
  factory HapticManager() => instance;
  HapticManager._internal();

  bool _isHapticEnabled = true;
  bool get isHapticEnabled => _isHapticEnabled;

  Future<void> initialize() async {
    final settings = await StorageEngine.instance.getSettings();
    _isHapticEnabled = settings['haptics'] as bool? ?? true;
  }

  Future<void> toggleHaptics() async {
    _isHapticEnabled = !_isHapticEnabled;
    final settings = await StorageEngine.instance.getSettings();
    settings['haptics'] = _isHapticEnabled;
    await StorageEngine.instance.saveSettings(settings);
    if (_isHapticEnabled) {
      await light();
    }
  }

  /// Subtle impact for UI clicks
  Future<void> light() async {
    if (!_isHapticEnabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Medium impact for buttons and rewards
  Future<void> medium() async {
    if (!_isHapticEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact for damage or big events
  Future<void> heavy() async {
    if (!_isHapticEnabled) return;
    await HapticFeedback.heavyImpact();
  }
}

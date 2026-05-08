import 'package:flutter/material.dart';

class LayoutBaseline extends ChangeNotifier {
  static final LayoutBaseline instance = LayoutBaseline._internal();
  factory LayoutBaseline() => instance;
  LayoutBaseline._internal();

  /// Pure Black background (OLED-friendly, immersive for Dark Fantasy)
  static const Color pureBlack = Colors.black;

  // We keep the logic for future padding colors, but default to Black
  Color _pillarboxColor = pureBlack;
  Color get pillarboxColor => _pillarboxColor;

  /// Resolution Baseline: 500x850 (Aspect Ratio ~1:1.7)
  static const double targetWidth = 500.0;
  static const double targetHeight = 850.0;
  static const double targetAspectRatio = targetWidth / targetHeight;

  /// Global Scale Factor: How much to scale the UI based on current dimensions.
  double _scale = 1.0;
  double get scale => _scale;

  /// Sets the current scale based on the actual height vs target height.
  void updateScale(double actualHeight) {
    final newScale = actualHeight / targetHeight;
    // Prevent infinite rebuilds due to floating-point inaccuracy
    if ((_scale - newScale).abs() > 0.001) {
      _scale = newScale;
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    // Default to black, we no longer support "white" padding to preserve aesthetic
    _pillarboxColor = pureBlack;
    notifyListeners();
  }
}

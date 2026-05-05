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

  Future<void> initialize() async {
    // Default to black, we no longer support "white" padding to preserve aesthetic
    _pillarboxColor = pureBlack;
    notifyListeners();
  }
}

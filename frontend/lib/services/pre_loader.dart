import 'package:flutter/material.dart';
import 'audio_service.dart';

/// Handles pre-loading of UI and Dashboard assets only.
/// This runs during the SplashScreen to ensure the main menu is snappy.
class PreLoader {
  static final List<String> imagesToPrecache = [
    'assets/images/dashboard/main_background.png',
    'assets/images/dashboard/background_1.png',
    'assets/images/dashboard/shop_stall.png',
    'assets/images/dashboard/roulette_man.png',
    'assets/images/dashboard/signage.png',
    'assets/images/dashboard/core/dorm.png',
    'assets/images/dashboard/auth/login_logo.png',
    'assets/images/dashboard/auth/register_logo.png',
    'assets/images/dashboard/core/splash_logo.png',
    'assets/images/dashboard/core/by_ryme.png',
  ];

  static final List<String> soundsToPrecache = [
    'audio/click.ogg',
    'audio/roulette.ogg',
    'audio/track1.ogg',
    'audio/track2.ogg',
  ];

  static Future<void> precacheAll(
    BuildContext context,
    Function(double progress) onProgress,
  ) async {
    int totalItems = imagesToPrecache.length + soundsToPrecache.length;
    int loadedCount = 0;

    for (var path in imagesToPrecache) {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
      loadedCount++;
      onProgress(loadedCount / totalItems);
    }

    for (var path in soundsToPrecache) {
      try {
        AudioService().precacheSound(path);
      } catch (_) {}
      loadedCount++;
      onProgress(loadedCount / totalItems);
    }
  }

  static int get totalCount => imagesToPrecache.length + soundsToPrecache.length;
}

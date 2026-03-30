import 'package:flutter/material.dart';
import 'audio_service.dart';

class PreLoader {
  static final List<String> imagesToPrecache = [
    'assets/images/dashboard/main_background.png',
    'assets/images/dashboard/background_1.png',
    'assets/images/dashboard/shop_stall.png',
    'assets/images/dashboard/roulette_man.png',
    'assets/images/dashboard/signage.png',
    'assets/images/game/environment/dorm.png',
  ];

  static final List<String> soundsToPrecache = [
    'audio/click.ogg',
    'audio/roulette.ogg',
    'audio/track1.ogg',
    'audio/track2.ogg',
    'audio/levelup.ogg',
    'audio/reward.ogg',
  ];

  /// Pre-caches all essential images and sounds, reporting progress.
  static Future<void> precacheAll(
    BuildContext context,
    Function(double progress) onProgress,
  ) async {
    int totalItems = imagesToPrecache.length + soundsToPrecache.length;
    int loadedCount = 0;

    // 1. Load Images
    for (var path in imagesToPrecache) {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (e) {
        debugPrint('Failed to precache image: $path - $e');
      }
      loadedCount++;
      onProgress(loadedCount / totalItems);
    }

    // 2. Load Sounds
    for (var path in soundsToPrecache) {
      try {
        await AudioService().precacheSound(path);
      } catch (e) {
        debugPrint('Failed to precache sound: $path - $e');
      }
      loadedCount++;
      onProgress(loadedCount / totalItems);
    }
  }

  /// Returns the total count of assets that need to be pre-cached.
  static int get totalCount => imagesToPrecache.length + soundsToPrecache.length;
}

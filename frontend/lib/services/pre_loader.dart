import 'package:flutter/material.dart';

class PreLoader {
  static final List<String> imagesToPrecache = [
    'assets/images/dashboard/main_background.png',
    'assets/images/dashboard/background_1.png',
    'assets/images/dashboard/shop_stall.png',
    'assets/images/dashboard/roulette_man.png',
    'assets/images/dashboard/signage.png',
    'assets/images/game/environment/dorm.png',
  ];

  /// Pre-caches all essential images and reports progress.
  static Future<void> precacheAll(
    BuildContext context,
    Function(double progress) onProgress,
  ) async {
    int loadedCount = 0;
    for (var path in imagesToPrecache) {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (e) {
        debugPrint('Failed to precache: $path - $e');
      }
      loadedCount++;
      onProgress(loadedCount / (imagesToPrecache.length + 1));
    }
  }

  /// Returns the total count of images that need to be pre-cached.
  static int get totalCount => imagesToPrecache.length;
}

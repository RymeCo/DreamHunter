import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/loading/game_loader.dart';

/// Handles pre-loading of UI, Dashboard, and Gameplay assets.
/// This runs during the SplashScreen to ensure the entire app experience is seamless.
class AppLoader {
  static final List<String> dashboardImages = [
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
    // 1. Calculate total items for accurate progress
    final gameImages = GameLoader.gameImages;
    int totalItems =
        dashboardImages.length + soundsToPrecache.length + gameImages.length;
    int loadedCount = 0;

    // 2. Precache Dashboard Images (Flutter Image Cache)
    for (var path in dashboardImages) {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
      loadedCount++;
      onProgress(loadedCount / totalItems);
    }

    // 3. Precache Sounds (AudioPlayers Cache)
    for (var path in soundsToPrecache) {
      try {
        AudioManager.instance.precacheSound(path);
      } catch (_) {}
      loadedCount++;
      onProgress(loadedCount / totalItems);
    }

    // 4. Precache Game Assets (Flame Image Cache)
    // By loading them into Flame's cache here, we ensure they are ready
    // and that Flame and Flutter can share the underlying memory if managed correctly.
    await GameLoader.loadGameAssets((gameProgress) {
      // Progress is handled internally here to keep overall progress accurate
    });

    loadedCount += gameImages.length;
    onProgress(1.0);
  }

  static int get totalCount =>
      dashboardImages.length +
      soundsToPrecache.length +
      GameLoader.gameImages.length;
}

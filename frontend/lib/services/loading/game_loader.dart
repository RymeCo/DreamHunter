import 'dart:async';
import 'dart:ui' as ui;
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

/// Handles loading and unloading of high-memory game assets.
/// Integrated with Flutter's ImageCache to prevent redundant memory usage.
class GameLoader {
  static final List<String> gameImages = [
    // Characters
    'game/characters/nun_front-32x48.png',
    'game/characters/nun_back-32x48.png',
    'game/characters/max_front-32x48.png',
    'game/characters/max_back-32x48.png',
    'game/characters/jack_front-32x48.png',
    'game/characters/jack_back-32x48.png',

    // Monsters
    'game/monsters/ghost_idle-32x48.png',
    'game/monsters/ghost_right-32x48.png',
    'game/monsters/ghost_back-32x48.png',

    // Economy & Defense
    'game/economy/bed-32x32.png',
    'game/economy/generator_lv1-32x32.png',
    'game/economy/generator_lv2-32x32.png',
    'game/economy/generator_lv3-32x32.png',
    'game/defenses/door_wood-32x32.png',
    'game/defenses/door_wood_open-32x32.png',
    'game/defenses/turret_sheet-32x32.png',
    'tiles/floor_tiles-32x32.png',
  ];

  /// Loads all match-specific images into Flame's memory cache.
  /// Uses Flutter's cache to ensure zero redundancy.
  static Future<void> loadGameAssets(
    Function(double progress) onProgress,
  ) async {
    int loaded = 0;

    for (var path in gameImages) {
      try {
        // 1. Resolve the asset via Flutter's mechanism (uses ImageCache if available)
        final imageProvider = AssetImage('assets/images/$path');
        final Completer<ui.Image> completer = Completer<ui.Image>();
        final ImageStream stream = imageProvider.resolve(
          ImageConfiguration.empty,
        );

        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (ImageInfo info, bool synchronousCall) {
            if (!completer.isCompleted) {
              completer.complete(info.image);
            }
            stream.removeListener(listener);
          },
          onError: (exception, stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(exception, stackTrace);
            }
            stream.removeListener(listener);
          },
        );

        stream.addListener(listener);

        // Safety timeout to prevent hanging the whole game transition
        final ui.Image image = await completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            throw TimeoutException('Asset load timed out: $path');
          },
        );

        // 2. Add the resolved image to Flame's internal cache
        Flame.images.add(path, image);

        // 3. Rasterization Warmup: Force the GPU to "see" the image by drawing it
        // This prevents the "first frame stutter" when entering the game.
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawImage(image, Offset.zero, Paint());
        recorder.endRecording().dispose();
      } catch (e) {
        // Skipping asset
      }
      loaded++;
      onProgress(loaded / gameImages.length);
    }
  }

  /// Wipes match assets from memory. Call this when the player exits the game!
  static void unloadGameAssets() {
    // Aggressive disposal to prevent memory leaks and lag in dashboard
    Flame.images.clearCache();
    Flame.assets.clearCache();
  }
}

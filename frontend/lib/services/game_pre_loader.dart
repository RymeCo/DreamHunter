import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';

/// Handles loading and unloading of high-memory game assets.
/// These assets are only loaded when the match starts and are WIPED when the match ends.
class GamePreLoader {
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
  ];

  /// Loads all match-specific images into Flame's memory cache.
  static Future<void> loadGameAssets(Function(double progress) onProgress) async {
    int loaded = 0;
    for (var path in gameImages) {
      try {
        await Flame.images.load(path);
      } catch (e) {
        debugPrint('Failed to load game asset: $path - $e');
      }
      loaded++;
      onProgress(loaded / gameImages.length);
    }
  }

  /// Wipes match assets from memory. Call this when the player exits the game!
  static void unloadGameAssets() {
    for (var path in gameImages) {
      Flame.images.clear(path);
    }
    debugPrint('Game Assets Wiped from Memory.');
  }
}

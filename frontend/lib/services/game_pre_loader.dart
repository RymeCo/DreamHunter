import 'package:flame/flame.dart';

class GamePreLoader {
  static final List<String> characterImages = [
    'game/characters/man/facing-front(32x64).png',
    'game/characters/man/facing-back(32x64).png',
    'game/characters/lady/facing-front(32x64).png',
    'game/characters/lady/facing-back(32x64).png',
    'game/characters/boy/facing-front(32x64).png',
    'game/characters/boy/facing-back(32x64).png',
  ];

  static final List<String> tileImages = [
    'tiles/bed_blue_32x64.png',
    'tiles/door_32x32.png',
    'tiles/floor_1_16.png',
  ];

  static Future<void> preload(
    Function(double progress) onProgress,
  ) async {
    final allImages = [...characterImages, ...tileImages];
    int loaded = 0;

    for (var path in allImages) {
      await Flame.images.load(path);
      loaded++;
      onProgress(loaded / allImages.length);
    }
  }
}

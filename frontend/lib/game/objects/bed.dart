import 'dart:async';
import 'package:flame/components.dart';
import 'package:dreamhunter/game/dreamhunter_game.dart';

class Bed extends SpriteComponent with HasGameReference<DreamHunterGame> {
  Bed({
    required super.position,
    required super.size,
  });

  @override
  FutureOr<void> onLoad() async {
    priority = 1;
    // We adjust the size to 32x64 to match the sprite, 
    // even if the TMX object height is smaller (e.g., 48).
    // This ensures the bed doesn't look squashed.
    size = Vector2(32, 64);
    // Since objects in Tiled are usually top-left, we might need 
    // to adjust the Y position if we're increasing the height.
    // If the object was 48, and we increase to 64, we move it up by 16.
    // But for now, let's keep it simple.
    sprite = await game.loadSprite('tiles/bed_blue_32x64.png',
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(32, 64),
    );
    return super.onLoad();
  }
}

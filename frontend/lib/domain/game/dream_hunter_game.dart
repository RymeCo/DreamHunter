import 'dart:async';
import 'package:dreamhunter/domain/game/level/level.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';

class DreamHunterGame extends FlameGame with HasKeyboardHandlerComponents {
  late final CameraComponent cam;
  final world = World();

  @override
  FutureOr<void> onLoad() async {
    // Load all assets into cache
    await images.loadAllImages();

    final level = Level(
      fileName: 'map/map 1.json',
      destTileSize: Vector2.all(32),
    );

    await world.add(level);

    cam = CameraComponent.withFixedResolution(
      world: world,
      width: 640,
      height: 360,
    );
    cam.viewfinder.anchor = Anchor.topLeft;

    addAll([cam, world]);

    return super.onLoad();
  }
}

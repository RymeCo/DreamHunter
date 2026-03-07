import 'dart:async';
import 'package:dreamhunter/domain/game/level/level.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';

class DreamHunterGame extends FlameGame with HasKeyboardHandlerComponents {
  late final CameraComponent cam;

  @override
  final World world = World();

  @override
  FutureOr<void> onLoad() async {
    // Set prefix to empty since our assets are in assets/ (not assets/images/)
    images.prefix = '';
    
    // Load all assets into cache
    await images.loadAllImages();

    final level = Level(
      fileName: 'map_1.json',
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

import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:dreamhunter/game/dreamhunter_game.dart';
import '../level/collision_block.dart';

class Door extends SpriteComponent
    with HasGameReference<DreamHunterGame>, TapCallbacks {
  bool isOpen;
  late final Sprite _closedSprite;
  late final Sprite _openSprite;
  final CollisionBlock collisionBlock;

  Door({required Vector2 position, required Vector2 size, this.isOpen = false})
    : collisionBlock = CollisionBlock(
        position: position.clone(),
        size: size.clone(),
        isPassable: isOpen,
      ),
      super(position: position, size: size);

  @override
  FutureOr<void> onLoad() async {
    priority = 1;

    _closedSprite = await game.loadSprite(
      'tiles/door_32x32.png',
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(32, 32),
    );

    _openSprite = await game.loadSprite(
      'tiles/door_32x32.png',
      srcPosition: Vector2(32, 0),
      srcSize: Vector2(32, 32),
    );

    sprite = isOpen ? _openSprite : _closedSprite;

    return super.onLoad();
  }

  void toggleDoor() {
    isOpen = !isOpen;
    sprite = isOpen ? _openSprite : _closedSprite;
    collisionBlock.isPassable = isOpen;
  }

  @override
  void onTapDown(TapDownEvent event) {
    toggleDoor();
  }
}

import 'package:flame/components.dart';
import 'package:dreamhunter/game/dreamhunter_game.dart';
import '../level/collision_block.dart';

enum PlayerState { facingFront, facingBack }

class Player extends SpriteComponent with HasGameReference<DreamHunterGame> {
  final JoystickComponent joystick;
  final String characterType;
  final Vector2 spriteSize;
  
  double speed = 200.0;
  PlayerState _state = PlayerState.facingFront;
  
  final Vector2 hitboxSize = Vector2(32, 32);
  
  List<CollisionBlock> collisionBlocks = [];

  Player({
    required this.joystick, 
    required this.characterType,
    Vector2? size,
  }) : spriteSize = size ?? Vector2(32, 64);

  @override
  Future<void> onLoad() async {
    final sizeStr = '${spriteSize.x.toInt()}x${spriteSize.y.toInt()}';
    sprite = await game.loadSprite('game/characters/$characterType/facing-front ($sizeStr).png');
    
    size = spriteSize;
    anchor = Anchor.bottomCenter;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!joystick.delta.isZero()) {
      _updatePlayerMovement(dt);
    }
  }

  void _updatePlayerMovement(double dt) {
    final movement = joystick.relativeDelta * speed * dt;

    position.x += movement.x;
    _checkHorizontalCollisions();

    position.y += movement.y;
    _checkVerticalCollisions();

    if (joystick.relativeDelta.x < -0.1) {
      if (scale.x > 0) scale.x = -1;
    } else if (joystick.relativeDelta.x > 0.1) {
      if (scale.x < 0) scale.x = 1;
    }

    if (joystick.relativeDelta.y < -0.1) {
      if (_state != PlayerState.facingBack) {
        _state = PlayerState.facingBack;
        _updateSprite();
      }
    } else if (joystick.relativeDelta.y > 0.1) {
      if (_state != PlayerState.facingFront) {
        _state = PlayerState.facingFront;
        _updateSprite();
      }
    } else if (joystick.relativeDelta.x.abs() > 0.1) {
      if (_state != PlayerState.facingFront) {
        _state = PlayerState.facingFront;
        _updateSprite();
      }
    }
  }

  void _checkHorizontalCollisions() {
    for (final block in collisionBlocks) {
      if (block.isPassable) continue;

      if (_checkCollision(block)) {
        if (joystick.relativeDelta.x > 0) {
          position.x = block.x - hitboxSize.x / 2;
        } else if (joystick.relativeDelta.x < 0) {
          position.x = block.x + block.width + hitboxSize.x / 2;
        }
      }
    }
  }

  void _checkVerticalCollisions() {
    for (final block in collisionBlocks) {
      if (block.isPassable) continue;

      if (_checkCollision(block)) {
        if (joystick.relativeDelta.y > 0) {
          position.y = block.y;
        } else if (joystick.relativeDelta.y < -0.1) {
          position.y = block.y + block.height + hitboxSize.y;
        }
      }
    }
  }

  bool _checkCollision(CollisionBlock block) {
    final hitboxLeft = position.x - hitboxSize.x / 2;
    final hitboxRight = position.x + hitboxSize.x / 2;
    final hitboxBottom = position.y;
    final hitboxTop = position.y - hitboxSize.y;

    final blockLeft = block.x;
    final blockRight = block.x + block.width;
    final blockTop = block.y;
    final blockBottom = block.y + block.height;

    return (hitboxLeft < blockRight &&
            hitboxRight > blockLeft &&
            hitboxTop < blockBottom &&
            hitboxBottom > blockTop);
  }

  Future<void> _updateSprite() async {
    final stateStr = _state == PlayerState.facingBack ? 'back' : 'front';
    final sizeStr = '${spriteSize.x.toInt()}x${spriteSize.y.toInt()}';
    sprite = await game.loadSprite('game/characters/$characterType/facing-$stateStr ($sizeStr).png');
  }
}

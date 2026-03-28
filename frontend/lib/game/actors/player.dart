import 'package:flame/components.dart';
import 'package:dreamhunter/game/dreamhunter_game.dart';
import '../level/collision_block.dart';
import '../objects/bed.dart';

enum PlayerState { facingFront, facingBack, sleeping }

class Player extends SpriteComponent with HasGameReference<DreamHunterGame> {
  final JoystickComponent joystick;
  final String characterType;
  final Vector2 spriteSize;
  
  double speed = 200.0;
  PlayerState _state = PlayerState.facingFront;
  
  final Vector2 hitboxSize = Vector2(32, 32);
  
  List<CollisionBlock> collisionBlocks = [];
  List<Bed> beds = [];
  Bed? currentBed;
  bool isNearBed = false;
  double energy = 0;

  Player({
    required this.joystick, 
    required this.characterType,
    Vector2? size,
  }) : spriteSize = size ?? Vector2(32, 64);

  @override
  Future<void> onLoad() async {
    final sizeStr = '${spriteSize.x.toInt()}x${spriteSize.y.toInt()}';
    sprite = await game.loadSprite('game/characters/$characterType/facing-front($sizeStr).png');
    
    size = spriteSize;
    anchor = Anchor.bottomCenter;
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (_state == PlayerState.sleeping) {
      energy += 1.0 * dt;
      return;
    }

    _checkBedProximity();

    if (!joystick.delta.isZero()) {
      _updatePlayerMovement(dt);
    }
  }

  void _checkBedProximity() {
    bool near = false;
    Bed? foundBed;
    
    for (final bed in beds) {
      if (_checkOverlap(bed)) {
        near = true;
        foundBed = bed;
        break;
      }
    }
    
    isNearBed = near;
    currentBed = foundBed;
  }

  void enterBed() {
    if (currentBed != null) {
      _state = PlayerState.sleeping;
      // Center player on bed
      position = Vector2(currentBed!.x + currentBed!.width / 2, currentBed!.y + currentBed!.height);
      _updateSprite();
    }
  }

  void exitBed() {
    _state = PlayerState.facingFront;
    _updateSprite();
  }

  PlayerState get state => _state;

  void _updatePlayerMovement(double dt) {
    final movement = joystick.relativeDelta * speed * dt;

    position.x += movement.x;
    _checkHorizontalCollisions();

    position.y += movement.y;
    _checkVerticalCollisions();

    if (joystick.relativeDelta.x < 0) {
      if (scale.x > 0) scale.x = -1;
    } else if (joystick.relativeDelta.x > 0) {
      if (scale.x < 0) scale.x = 1;
    }

    if (joystick.relativeDelta.y < 0) {
      if (_state != PlayerState.facingBack) {
        _state = PlayerState.facingBack;
        _updateSprite();
      }
    } else if (joystick.relativeDelta.y > 0) {
      if (_state != PlayerState.facingFront) {
        _state = PlayerState.facingFront;
        _updateSprite();
      }
    } else if (joystick.relativeDelta.x.abs() > 0) {
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
        } else if (joystick.relativeDelta.y < 0) {
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

  bool _checkOverlap(PositionComponent other) {
    final hitboxLeft = position.x - hitboxSize.x / 2;
    final hitboxRight = position.x + hitboxSize.x / 2;
    final hitboxBottom = position.y;
    final hitboxTop = position.y - hitboxSize.y;

    final otherLeft = other.x;
    final otherRight = other.x + other.width;
    final otherTop = other.y;
    final otherBottom = other.y + other.height;

    return (hitboxLeft < otherRight &&
            hitboxRight > otherLeft &&
            hitboxTop < otherBottom &&
            hitboxBottom > otherTop);
  }

  Future<void> _updateSprite() async {
    if (_state == PlayerState.sleeping) {
      // Hide or show special sleeping sprite if needed
      opacity = 0.7; // Just a placeholder effect
      return;
    }
    opacity = 1.0;
    final stateStr = _state == PlayerState.facingBack ? 'back' : 'front';
    final sizeStr = '${spriteSize.x.toInt()}x${spriteSize.y.toInt()}';
    sprite = await game.loadSprite('game/characters/$characterType/facing-$stateStr($sizeStr).png');
  }
}

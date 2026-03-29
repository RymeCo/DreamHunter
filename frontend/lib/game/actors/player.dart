import 'package:flame/components.dart';
import 'package:dreamhunter/game/dreamhunter_game.dart';
import 'dart:developer' as developer;
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

  Player({required this.joystick, required this.characterType, Vector2? size})
    : spriteSize = size ?? Vector2(32, 64);

  @override
  Future<void> onLoad() async {
    final sizeStr = '${spriteSize.x.toInt()}x${spriteSize.y.toInt()}';
    sprite = await game.loadSprite(
      'game/characters/$characterType/facing-front($sizeStr).png',
    );

    size = spriteSize;
    anchor = Anchor.topLeft;
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
      if (toRect().overlaps(bed.toRect())) {
        near = true;
        foundBed = bed;
        break;
      }
    }

    if (near != isNearBed) {
      developer.log('SCRUM-66: Near bed changed to: $near', name: 'Player');
    }
    isNearBed = near;
    currentBed = foundBed;
  }

  void enterBed() {
    if (currentBed != null) {
      _state = PlayerState.sleeping;
      // Center player on bed (TopLeft anchor)
      position = Vector2(
        currentBed!.x + (currentBed!.width - width) / 2,
        currentBed!.y + (currentBed!.height - height) / 2,
      );
      _updateSprite();
      developer.log('SCRUM-66: Player entered bed', name: 'Player');
    }
  }

  void exitBed() {
    _state = PlayerState.facingFront;
    _updateSprite();
    developer.log('SCRUM-66: Player exited bed', name: 'Player');
  }

  PlayerState get state => _state;

  void _updatePlayerMovement(double dt) {
    final movement = joystick.relativeDelta * speed * dt;

    position.x += movement.x;
    _checkHorizontalCollisions(movement.x);

    position.y += movement.y;
    _checkVerticalCollisions(movement.y);

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

  void _checkHorizontalCollisions(double dx) {
    for (final block in collisionBlocks) {
      if (block.isPassable) continue;

      if (toRect().overlaps(block.toRect())) {
        if (dx > 0) {
          position.x = block.x - width - 0.1; // Tiny buffer
        } else if (dx < 0) {
          position.x = block.x + block.width + 0.1;
        }
      }
    }
  }

  void _checkVerticalCollisions(double dy) {
    for (final block in collisionBlocks) {
      if (block.isPassable) continue;

      if (toRect().overlaps(block.toRect())) {
        if (dy > 0) {
          position.y = block.y - height - 0.1;
        } else if (dy < 0) {
          position.y = block.y + block.height + 0.1;
        }
      }
    }
  }

  Future<void> _updateSprite() async {
    if (_state == PlayerState.sleeping) {
      opacity = 0.7;
      return;
    }
    opacity = 1.0;
    final stateStr = _state == PlayerState.facingBack ? 'back' : 'front';
    final sizeStr = '${spriteSize.x.toInt()}x${spriteSize.y.toInt()}';
    sprite = await game.loadSprite(
      'game/characters/$characterType/facing-$stateStr($sizeStr).png',
    );
  }
}

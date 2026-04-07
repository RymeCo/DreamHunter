import 'package:flame/components.dart';
import '../haunted_dorm_game.dart';
import '../level/collision_block.dart';
import '../objects/bed.dart';

enum AIHunterState { wandering, claiming, sleeping }

class AIHunter extends SpriteComponent with HasGameReference<HauntedDormGame> {
  final String characterType;
  final Vector2 spriteSize;
  double speed = 100.0;
  bool isMovingBack = false;

  AIHunterState _state = AIHunterState.wandering;
  List<CollisionBlock> collisionBlocks = [];
  List<Bed> beds = [];
  Bed? targetBed;

  AIHunter({required this.characterType, Vector2? size})
    : spriteSize = size ?? Vector2(32, 48);

  @override
  Future<void> onLoad() async {
    final fileName = 'game/characters/${characterType}_front-32x48.png';
    sprite = await game.loadSprite(fileName);
    size = spriteSize;
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_state == AIHunterState.sleeping) return;

    if (_state == AIHunterState.claiming && targetBed != null) {
      // AI Vision: Check if the door to their target room is closed
      for (final door in game.level.allDoors) {
        if (door.associatedBed == targetBed && !door.isOpen) {
          // Door is closed! Yield and find another room.
          yieldBed();
          return;
        }
      }
      _moveToTarget(dt);
    }
  }

  void _moveToTarget(double dt) {
    if (targetBed == null) return;

    // AI targets slightly above the bed to align with the pillow
    final targetPos = targetBed!.position + (targetBed!.size / 2);
    final direction = targetPos - position;
    
    if (direction.length < 2) {
      _enterBed();
      return;
    }

    final velocity = direction.normalized() * speed * dt;
    position += velocity;

    // Asymmetrical Mirroring: Scale -1 around the CENTER anchor
    if (velocity.x < 0) {
      if (scale.x > 0) scale.x = -1;
      if (isMovingBack) {
        isMovingBack = false;
        _updateSprite();
      }
    } else if (velocity.x > 0) {
      if (scale.x < 0) scale.x = 1;
      if (isMovingBack) {
        isMovingBack = false;
        _updateSprite();
      }
    }

    if (velocity.y < -0.5) {
      if (!isMovingBack) {
        isMovingBack = true;
        _updateSprite();
      }
    } else if (velocity.y > 0.5) {
      if (isMovingBack) {
        isMovingBack = false;
        _updateSprite();
      }
    }
  }

  void _enterBed() {
    if (targetBed != null) {
      _state = AIHunterState.sleeping;
      // Center AI on bed
      position = targetBed!.position + (targetBed!.size / 2);
      _updateSprite();
    }
  }

  void yieldBed() {
    if (_state == AIHunterState.sleeping || _state == AIHunterState.claiming) {
      _state = AIHunterState.wandering;
      targetBed = null;
    }
  }

  void setTargetBed(Bed bed) {
    targetBed = bed;
    _state = AIHunterState.claiming;
  }

  Future<void> _updateSprite() async {
    final suffix = isMovingBack ? 'back' : 'front';
    final fileName = 'game/characters/${characterType}_$suffix-32x48.png';

    if (_state == AIHunterState.sleeping) {
      sprite = await game.loadSprite(
        fileName,
        srcPosition: Vector2(0, 0),
        srcSize: Vector2(32, 24),
      );
      size = Vector2(32, 24);
      return;
    }

    size = spriteSize;
    sprite = await game.loadSprite(fileName);
  }
}

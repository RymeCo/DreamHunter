import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../haunted_dorm_game.dart';
import '../level/collision_block.dart';
import '../objects/bed.dart';

enum PlayerState { wandering, sleeping }

class Player extends SpriteComponent with HasGameReference<HauntedDormGame> {
  final JoystickComponent joystick;
  final String characterType;
  final Vector2 spriteSize;

  double speed = 200.0;
  PlayerState _state = PlayerState.wandering;
  bool isMovingBack = false;

  List<CollisionBlock> collisionBlocks = [];
  List<Bed> beds = [];
  Bed? currentBed;
  bool isNearBed = false;
  double energy = 0;

  Player({required this.joystick, required this.characterType, Vector2? size})
    : spriteSize = size ?? Vector2(32, 48);

  @override
  Future<void> onLoad() async {
    final fileName = 'game/characters/${characterType}_front-32x48.png';
    sprite = await game.loadSprite(fileName);
    size = spriteSize;
    anchor = Anchor.center;
    priority = 5;
  }

  Rect _getFootHitbox(Vector2 pos) {
    return Rect.fromCenter(
      center: Offset(pos.x, pos.y + (height / 2) - 6),
      width: 20,
      height: 12,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_state == PlayerState.sleeping) {
      if (joystick.scale != Vector2.zero()) joystick.scale = Vector2.zero();
      return;
    } else {
      if (joystick.scale != Vector2.all(1.0)) joystick.scale = Vector2.all(1.0);
    }

    _checkBedProximity();

    if (!joystick.delta.isZero()) {
      _updatePlayerMovement(dt);
    }
  }

  void _checkBedProximity() {
    bool near = false;
    Bed? foundBed;
    final footRect = _getFootHitbox(position);

    for (final bed in beds) {
      if (footRect.overlaps(bed.toRect())) {
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
      
      // FIX: Better head alignment on the 32x32 bed
      position = Vector2(currentBed!.x + 16, currentBed!.y + 6);
      
      currentBed!.setSleeping(true);
      
      // AUTO-CLOSE: Find the Door strictly linked to this Bed
      for (final door in game.level.allDoors) {
        if (door.associatedBed == currentBed) {
          door.closeDoor();
          break;
        }
      }
      
      _updateSprite();
      _startEconomyTicks();
    }
  }

  void _startEconomyTicks() {
    Future.doWhile(() async {
      if (_state != PlayerState.sleeping) return false;
      await Future.delayed(const Duration(milliseconds: 500));
      if (_state == PlayerState.sleeping) {
        energy += 1;
        _showFloatingText('+1');
        return true;
      }
      return false;
    });
  }

  void _showFloatingText(String text) {
    final textComponent = TextComponent(
      text: text,
      position: Vector2(position.x, position.y - 20),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.amberAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    
    game.level.add(textComponent);

    textComponent.add(MoveByEffect(
      Vector2(0, -40),
      EffectController(duration: 0.6),
      onComplete: () => textComponent.removeFromParent(),
    ));
  }

  void exitBed() {
    if (currentBed != null) {
      currentBed!.setSleeping(false);
    }
    _state = PlayerState.wandering;
    _updateSprite();
  }

  PlayerState get state => _state;

  void _updatePlayerMovement(double dt) {
    final movement = joystick.relativeDelta * speed * dt;

    final oldX = position.x;
    position.x += movement.x;
    if (_checkCollisions()) position.x = oldX;

    final oldY = position.y;
    position.y += movement.y;
    if (_checkCollisions()) position.y = oldY;

    if (joystick.relativeDelta.x < 0) {
      if (scale.x > 0) scale.x = -1;
      if (isMovingBack) {
        isMovingBack = false;
        _updateSprite();
      }
    } else if (joystick.relativeDelta.x > 0) {
      if (scale.x < 0) scale.x = 1;
      if (isMovingBack) {
        isMovingBack = false;
        _updateSprite();
      }
    }

    if (joystick.relativeDelta.y < -0.5) {
      if (!isMovingBack) {
        isMovingBack = true;
        _updateSprite();
      }
    } else if (joystick.relativeDelta.y > 0.5) {
      if (isMovingBack) {
        isMovingBack = false;
        _updateSprite();
      }
    }
  }

  bool _checkCollisions() {
    final footRect = _getFootHitbox(position);
    for (final block in collisionBlocks) {
      if (!block.isPassable && footRect.overlaps(block.toRect())) return true;
    }
    return false;
  }

  Future<void> _updateSprite() async {
    final suffix = isMovingBack ? 'back' : 'front';
    final fileName = 'game/characters/${characterType}_$suffix-32x48.png';
    
    if (_state == PlayerState.sleeping) {
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

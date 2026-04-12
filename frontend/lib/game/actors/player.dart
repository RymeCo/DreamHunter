import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
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
  double coins = 0;
  double _economyTimer = 0;

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
      if (joystick.scale != Vector2.zero()) {
        joystick.scale = Vector2.zero();
        game.camera.stop(); // FREE CAM: Unlock camera from player
      }

      // Frame-safe, pause-aware economy loop
      if (!game.isGracePeriod) {
        _economyTimer += dt;
        if (_economyTimer >= 0.5) {
          _economyTimer = 0;
          energy += 1;
          coins += 1;
          _showFloatingText('+1');
        }
      }
      return;
    } else {
      if (joystick.scale != Vector2.all(1.0)) {
        joystick.scale = Vector2.all(1.0);
        game.camera.follow(this); // Lock camera back to player
      }
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

      // FIX: Position head exactly on the pillow (Top of the 32x32 bed)
      position = currentBed!.position + Vector2(16, -8);

      currentBed!.setSleeping(true);

      // AUTO-CLOSE: Find the Door strictly linked to this Bed
      bool doorFound = false;
      for (final door in game.level.allDoors) {
        if (door.roomID == currentBed!.roomID) {
          developer.log(
            'Room Match Found! Closing door ID: ${door.roomID}',
            name: 'Player',
          );
          door.closeDoor();
          doorFound = true;
          break;
        }
      }

      if (!doorFound) {
        developer.log(
          'ERROR: No Door found for Room ID: ${currentBed!.roomID}. Map Scan Gap!',
          name: 'Player',
        );
      }

      _updateSprite();
    }
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

    textComponent.add(
      MoveByEffect(
        Vector2(0, -40),
        EffectController(duration: 0.6),
        onComplete: () => textComponent.removeFromParent(),
      ),
    );
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

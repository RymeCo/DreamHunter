import 'dart:async';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:dreamhunter/domain/game/dream_hunter_game.dart';

import 'package:dreamhunter/domain/game/playground_service.dart';

enum PlayerState { idleFront, idleBack, walkFront, walkBack }

class Player extends SpriteAnimationGroupComponent<PlayerState>
    with HasGameReference<DreamHunterGame>, CollisionCallbacks {
  final PlaygroundService _service = PlaygroundService();
  final double stepTime = 0.1;
  final double moveSpeed = 200;
  final double gravity = 9.8;
  final double jumpForce = 450;
  final double terminalVelocity = 300;

  Vector2 velocity = Vector2.zero();
  bool isOnGround = false;
  JoystickComponent joystick;

  Player({
    super.position,
    required this.joystick,
  }) : super(size: Vector2.all(32));

  @override
  FutureOr<void> onLoad() async {
    _loadAllAnimations();
    add(RectangleHitbox());
    return super.onLoad();
  }

  @override
  void update(double dt) {
    _applyGravity(dt);
    _updatePlayerMovement(dt);
    _updatePlayerState();
    super.update(dt);
  }

  void _loadAllAnimations() {
    // Dynamically load the character sprite based on selection
    final spritePath = 'assets/sprites/character/${_service.selectedCharacter}.png';
    final spriteSheet = game.images.fromCache(spritePath);

    // Assumes Row 0 = Front, Row 1 = Back (Adjust textureY if different)
    animations = {
      PlayerState.idleFront: SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 1,
          stepTime: stepTime,
          textureSize: Vector2.all(32),
          texturePosition: Vector2(0, 0),
        ),
      ),
      PlayerState.idleBack: SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 1,
          stepTime: stepTime,
          textureSize: Vector2.all(32),
          texturePosition: Vector2(0, 32),
        ),
      ),
      PlayerState.walkFront: SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 1, // Update this if you have multiple frames for walking
          stepTime: stepTime,
          textureSize: Vector2.all(32),
          texturePosition: Vector2(0, 0),
        ),
      ),
      PlayerState.walkBack: SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 1,
          stepTime: stepTime,
          textureSize: Vector2.all(32),
          texturePosition: Vector2(0, 32),
        ),
      ),
    };

    current = PlayerState.idleFront;
  }

  void _applyGravity(double dt) {
    velocity.y += gravity;
    velocity.y = velocity.y.clamp(-jumpForce, terminalVelocity);
    position.y += velocity.y * dt;
  }

  void _updatePlayerMovement(double dt) {
    if (joystick.direction != JoystickDirection.idle) {
      velocity.x = joystick.relativeDelta.x * moveSpeed;
      position.x += velocity.x * dt;

      if (joystick.relativeDelta.y < -0.5 && isOnGround) {
        _jump();
      }

      // Flip sprite based on horizontal direction
      if (joystick.relativeDelta.x < 0 && scale.x > 0) {
        flipHorizontallyAroundCenter();
      } else if (joystick.relativeDelta.x > 0 && scale.x < 0) {
        flipHorizontallyAroundCenter();
      }
    } else {
      velocity.x = 0;
    }
  }

  void _updatePlayerState() {
    PlayerState nextState = PlayerState.idleFront;

    if (velocity.x != 0 || velocity.y != 0) {
      // Determine if moving Up or Down
      if (joystick.relativeDelta.y < 0) {
        nextState = PlayerState.walkBack;
      } else {
        nextState = PlayerState.walkFront;
      }
    } else {
      // Default to Idle Front for now
      nextState = PlayerState.idleFront;
    }

    current = nextState;
  }

  void _jump() {
    velocity.y = -jumpForce;
    isOnGround = false;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    // If we hit anything, for now we assume it's the door if it's not the floor
    // In a full implementation, we'd check tile properties.
    if (other is TiledComponent) {
      // Basic door detection logic: if we are at the door's approximate location
      // Or we can just trigger it for testing
      // game.triggerWin(); 
    }
    
    if (velocity.y > 0) {
...      if (position.y + size.y > other.position.y &&
          position.y < other.position.y) {
        velocity.y = 0;
        position.y = other.position.y - size.y;
        isOnGround = true;
      }
    }
    super.onCollision(intersectionPoints, other);
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    isOnGround = false;
    super.onCollisionEnd(other);
  }
}

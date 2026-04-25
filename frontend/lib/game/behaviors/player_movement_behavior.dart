import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/player_entity.dart';
import 'package:dreamhunter/game/ui/dynamic_joystick.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';

/// Handles movement logic for the PlayerEntity using a Joystick.
/// Includes collision detection with map obstacles and allows sliding.
class PlayerMovementBehavior extends Component with ParentIsA<PlayerEntity>, HasGameReference<DreamHunterGame> {
  final DynamicJoystick joystick;
  final double speed = 150.0;

  PlayerMovementBehavior({required this.joystick});

  @override
  void update(double dt) {
    super.update(dt);

    if (joystick.isActive && !joystick.relativeDelta.isZero()) {
      final velocity = joystick.relativeDelta * speed;
      
      // Calculate potential new positions
      final nextX = parent.position.x + (velocity.x * dt);
      final nextY = parent.position.y + (velocity.y * dt);

      // Get the current hitbox size and offset from BaseEntity
      // Hitbox is roughly (size.x * 0.75, size.y * 0.25) at (size.x * 0.125, size.y * 0.75)
      final hbWidth = parent.size.x * 0.75;
      final hbHeight = parent.size.y * 0.25;
      final hbOffsetX = parent.size.x * 0.125;
      final hbOffsetY = parent.size.y * 0.75;

      // Check X movement
      final hitboxX = Rect.fromLTWH(
        nextX - (parent.anchor.x * parent.size.x) + hbOffsetX,
        parent.position.y - (parent.anchor.y * parent.size.y) + hbOffsetY,
        hbWidth,
        hbHeight,
      );

      if (!game.isPositionBlocked(hitboxX)) {
        parent.position.x = nextX;
      }

      // Check Y movement
      final hitboxY = Rect.fromLTWH(
        parent.position.x - (parent.anchor.x * parent.size.x) + hbOffsetX,
        nextY - (parent.anchor.y * parent.size.y) + hbOffsetY,
        hbWidth,
        hbHeight,
      );

      if (!game.isPositionBlocked(hitboxY)) {
        parent.position.y = nextY;
      }
      
      // Flip sprite based on movement direction
      if (joystick.relativeDelta.x < 0) {
        parent.scale.x = -1; // Face left
      } else if (joystick.relativeDelta.x > 0) {
        parent.scale.x = 1; // Face right
      }
    }
  }
}

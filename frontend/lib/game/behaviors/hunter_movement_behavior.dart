import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:dreamhunter/game/entities/hunter_ai_entity.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/game/entities/bed_entity.dart';

/// The simplest possible movement behavior.
/// AI follows its target bed's Flow Field (Gravity Map) using a smooth gradient.
class HunterMovementBehavior extends Component
    with ParentIsA<HunterAIEntity>, HasGameReference<DreamHunterGame> {
  /// AI Speed is 80.0 (Slower than the player's 150.0 base speed)
  final double speed = 80.0;

  @override
  void update(double dt) {
    super.update(dt);

    if (parent.isSleeping) return;

    // 1. RE-PATHING LOGIC: Check if target bed was stolen or if we are homeless
    if (parent.targetBed.isOccupied && parent.targetBed.owner != parent) {
      _findNewBed();
    }

    // 2. Are we at the bed?
    final distToBed = parent.position.distanceTo(parent.targetBed.position);
    if (distToBed < 40.0) {
      if (!parent.targetBed.isOccupied) {
        parent.targetBed.occupy(parent);
        parent.sleep(parent.targetBed.position);
      } else {
        // Bed was taken just as we arrived!
        _findNewBed();
      }
      return;
    }

    // 3. Find target tile using Flow Field (Lazy Loaded)
    final flowField = game.getFlowField(parent.targetBed.roomID);
    if (flowField == null) {
      // If we can't find a flow field, maybe the room is invalid or map changed.
      _findNewBed();
      return;
    }

    final curX = (parent.position.x / 32)
        .floor()
        .clamp(0, DreamHunterGame.gridW - 1)
        .toInt();
    final curY = (parent.position.y / 32)
        .floor()
        .clamp(0, DreamHunterGame.gridH - 1)
        .toInt();

    // Find best neighbor
    int bestDist = flowField[curX][curY];
    Vector2? targetCenter;

    for (final dir in [
      const math.Point(1, 0),
      const math.Point(-1, 0),
      const math.Point(0, 1),
      const math.Point(0, -1),
    ]) {
      final nx = curX + dir.x;
      final ny = curY + dir.y;
      if (nx >= 0 &&
          nx < DreamHunterGame.gridW &&
          ny >= 0 &&
          ny < DreamHunterGame.gridH) {
        final d = flowField[nx][ny];
        if (d < bestDist) {
          bestDist = d;
          targetCenter = Vector2(nx * 32.0 + 16, ny * 32.0 + 16);
        }
      }
    }

    // 4. Move and Smoothly Center
    if (targetCenter != null) {
      final diff = targetCenter - parent.position;
      final direction = diff.normalized();

      // Move on the primary axis
      parent.position += direction * speed * dt;

      // "Center-Pulling" Logic: Lerp the perpendicular axis to keep AI in hallway center.
      // This prevents drifting into walls without causing jittery "snaps".
      const double pullStrength = 8.0;
      if (direction.x.abs() > direction.y.abs()) {
        // Moving Horizontal: Pull toward Y-center of the current row
        final centerY = curY * 32.0 + 16.0;
        parent.position.y += (centerY - parent.position.y) * pullStrength * dt;
      } else {
        // Moving Vertical: Pull toward X-center of the current column
        final centerX = curX * 32.0 + 16.0;
        parent.position.x += (centerX - parent.position.x) * pullStrength * dt;
      }

      // Sprite flipping
      if (direction.x < -0.1) {
        parent.scale.x = -1;
      } else if (direction.x > 0.1) {
        parent.scale.x = 1;
      }
    }
  }

  /// Clears current reservation and looks for the next best available room.
  void _findNewBed() {
    // 1. Cleanup old reservation immediately
    if (parent.targetBed.reservedBy == parent) {
      parent.targetBed.reservedBy = null;
    }

    // 2. CHECK PREFERRED BACKUPS FIRST (The "Backup Map")
    // This allows the AI to have a 'memory' of nearby rooms
    for (final backup in parent.preferredBeds) {
      if (!backup.isOccupied && backup.reservedBy == null) {
        parent.repathCount++;
        parent.targetBed = backup;
        parent.targetBed.reservedBy = parent;
        debugPrint('[AI] ${parent.skinPath} using BACKUP bed: ${parent.targetBed.roomID}');
        return;
      }
    }

    // 3. Fallback: Find ALL currently empty and unreserved beds if backups are full
    final otherBeds = game.roomBeds.values
        .where((b) => !b.isOccupied && b.reservedBy == null)
        .toList();

    if (otherBeds.isNotEmpty) {
      // Sort by distance to find the NEAREST one
      otherBeds.sort((a, b) => 
        parent.position.distanceToSquared(a.position).compareTo(
        parent.position.distanceToSquared(b.position))
      );
      
      // Assign new bed
      parent.repathCount++;
      parent.targetBed = otherBeds[0];
      parent.targetBed.reservedBy = parent;
      
      debugPrint('[AI] ${parent.skinPath} re-pathing to GLOBAL room ${parent.targetBed.roomID}');
    } else {
      // 4. Last Resort: Race for any unoccupied bed even if reserved
      final unoccupiedBeds = game.world.children
          .whereType<BedEntity>()
          .where((b) => !b.isOccupied)
          .toList();
          
      if (unoccupiedBeds.isNotEmpty) {
        unoccupiedBeds.sort((a, b) => 
          parent.position.distanceToSquared(a.position).compareTo(
          parent.position.distanceToSquared(b.position))
        );
        parent.targetBed = unoccupiedBeds[0];
      } else {
        debugPrint('[ERROR] ${parent.skinPath}: No empty beds found! I am homeless.');
      }
    }
  }
}

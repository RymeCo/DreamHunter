import 'dart:math' as math;
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

    // 1. Check if target bed was stolen
    if (parent.targetBed.isOccupied && parent.targetBed.owner != parent) {
      if (parent.repathCount < 5) {
        _findNewBed();
        return;
      }
    }

    // 2. Are we at the bed?
    final distToBed = parent.position.distanceTo(parent.targetBed.position);
    if (distToBed < 40.0) {
      parent.targetBed.occupy(parent);
      parent.sleep(parent.targetBed.position);
      return;
    }

    // 3. Find target tile using Flow Field (Lazy Loaded)
    final flowField = game.getFlowField(parent.targetBed.roomID);
    if (flowField == null) return;

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

  void _findNewBed() {
    final otherBeds = game.world.children
        .whereType<BedEntity>()
        .where((b) => !b.isOccupied && b.reservedBy == null)
        .toList();

    if (otherBeds.isNotEmpty) {
      // Cleanup old reservation
      parent.targetBed.reservedBy = null;

      // Assign new bed
      parent.repathCount++;
      parent.targetBed = otherBeds[0];
      parent.targetBed.reservedBy = parent;
    }
  }
}

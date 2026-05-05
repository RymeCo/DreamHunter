import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:dreamhunter/game/entities/hunter_ai_entity.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/game/entities/bed_entity.dart';
import 'package:dreamhunter/services/game/match_manager.dart';

/// The simplest possible movement behavior.
/// AI follows its target bed's Flow Field (Gravity Map) using a smooth gradient.
class HunterMovementBehavior extends Component
    with ParentIsA<HunterAIEntity>, HasGameReference<DreamHunterGame> {
  /// AI Speed is 80.0 (Slower than the player's 150.0 base speed)
  final double speed = 80.0;

  double _repathCooldown = 0;

  @override
  void update(double dt) {
    super.update(dt);

    if (parent.isSleeping) return;
    if (_repathCooldown > 0) _repathCooldown -= dt;

    // 1. RE-PATHING LOGIC: Check if target bed was stolen or if we are homeless
    if (parent.targetBed.isOccupied && parent.targetBed.owner != parent) {
      _findNewBed();
    }

    // 2. Are we at the bed?
    // We check distance to the bed center for more natural "snapping"
    final bedCenter = parent.targetBed.position + (parent.targetBed.size / 2);
    final distToBed = parent.position.distanceTo(bedCenter);
    
    if (distToBed < 32.0) { 
      if (!parent.targetBed.isOccupied) {
        parent.targetBed.occupy(parent);
        parent.sleep(parent.targetBed.position);
      } else {
        _findNewBed();
      }
      return;
    }

    // 3. Find target tile using Flow Field (Lazy Loaded)
    final flowField = game.getFlowField(parent.targetBed.roomID);
    if (flowField == null) {
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
    
    // FIX: If we are in the target tile (bestDist == 0) but not yet "sleeping" 
    // because the distance check failed, we must manually nudge toward the bed center.
    if (bestDist == 0) {
      final diff = bedCenter - parent.position;
      parent.position += diff.normalized() * speed * dt;
      return;
    }

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
      
      parent.position += direction * speed * dt;

      // Center-Pulling Logic
      const double pullStrength = 8.0;
      if (direction.x.abs() > direction.y.abs()) {
        final centerY = curY * 32.0 + 16.0;
        parent.position.y += (centerY - parent.position.y) * pullStrength * dt;
      } else {
        final centerX = curX * 32.0 + 16.0;
        parent.position.x += (centerX - parent.position.x) * pullStrength * dt;
      }

      // Sprite flipping
      if (direction.x < -0.1) {
        parent.scale.x = -1;
      } else if (direction.x > 0.1) {
        parent.scale.x = 1;
      }
    } else if (bestDist >= 9999) {
      // ONLY re-path if we are stuck AND have no valid neighbors (targetCenter == null)
      if (_repathCooldown <= 0) {
        debugPrint('[AI] ${parent.skinPath} truly stuck. Re-pathing...');
        _findNewBed();
        _repathCooldown = 1.0; // Prevent spam
      }
    }
  }

  /// Clears current reservation and looks for the next best available room.
  void _findNewBed() {
    // 1. Cleanup old reservation immediately
    if (parent.targetBed.reservedBy == parent) {
      parent.targetBed.reservedBy = null;
      MatchManager.instance.updateBedAvailability(parent.targetBed.roomID, true);
    }

    // 2. O(1) Lookup: Use pre-cached available beds from MatchManager
    final availableIDs = MatchManager.instance.availableBeds;

    if (availableIDs.isNotEmpty) {
      // Find nearest by iterating only over available IDs (Fast O(N) where N is small)
      BedEntity? bestBed;
      double minDist = double.infinity;

      for (final id in availableIDs) {
        final bed = game.roomBeds[id];
        if (bed == null) continue;
        
        final dist = parent.position.distanceToSquared(bed.position);
        if (dist < minDist) {
          minDist = dist;
          bestBed = bed;
        }
      }

      if (bestBed != null) {
        parent.repathCount++;
        parent.targetBed = bestBed;
        parent.targetBed.reservedBy = parent;
        MatchManager.instance.updateBedAvailability(bestBed.roomID, false);
        
        debugPrint('[AI] ${parent.skinPath} targeted: ${parent.targetBed.roomID}');
        return;
      }
    }
    
    // 3. Last Resort: Wander
    _wanderToHallway();
  }

  void _wanderToHallway() {
    // Pick a random direction and walk until we hit a wall or a long distance
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final wanderDir = Vector2(math.cos(angle), math.sin(angle));
    
    // We don't change targetBed here, but we nudge the position to simulate wandering
    // This prevents the "standing still" look while waiting for a room to potentially open.
    parent.position += wanderDir * (speed * 0.5); // Slower wander speed
  }
}

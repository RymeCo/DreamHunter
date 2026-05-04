import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:dreamhunter/game/entities/monster_entity.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/entities/door_entity.dart';
import 'package:dreamhunter/game/entities/bed_entity.dart';
import 'package:dreamhunter/game/entities/turret_entity.dart';
import 'package:dreamhunter/game/entities/player_entity.dart';
import 'package:dreamhunter/game/entities/hunter_ai_entity.dart';
import 'package:dreamhunter/game/components/floating_feedback.dart';
import 'package:dreamhunter/services/game/match_manager.dart';

enum MonsterState { idle, hunting, attacking, retreating }

class MonsterAIBehavior extends Component
    with ParentIsA<MonsterEntity>, HasGameReference<DreamHunterGame> {
  MonsterState state = MonsterState.idle;
  BaseEntity? target;
  List<Vector2> currentPath = [];
  int pathIndex = 0;

  double decisionTimer = 0;
  double attackTimer = 0;
  double _scanThrottleTimer = 0;

  double _frustrationTimer = 0;
  
  // Aggro Leashing
  double _chaseTimer = 0;
  static const double maxChaseTime = 8.0;

  final double stunCooldown = 10.0;
  final double stunDuration = 5.0;
  final double stunRange = 64.0;

  double _stuckTimer = 0;
  double _logThrottleTimer = 0;
  double _playerTargetingTimer = 0;
  double _stunCooldownValue = 0;
  math.Point<int>? _lastTile;

  @override
  void update(double dt) {
    super.update(dt);

    if (parent.isDestroyed) return;

    _scanThrottleTimer += dt;
    bool shouldScan = false;
    if (_scanThrottleTimer >= 0.25) {
      _scanThrottleTimer = 0;
      shouldScan = true;
    }

    if (state == MonsterState.hunting || state == MonsterState.retreating) {
      final currentTile = math.Point(
        (parent.position.x / 32).floor(),
        (parent.position.y / 32).floor(),
      );

      // FIX: Don't trigger stuck detection if we are retreating and already at a spawn point
      bool isAtSpawn = false;
      if (state == MonsterState.retreating) {
        for (final spawn in game.monsterSpawnPoints) {
          if (parent.position.distanceTo(spawn) < 20) {
            isAtSpawn = true;
            break;
          }
        }
      }

      if (currentTile == _lastTile && !isAtSpawn) {
        _stuckTimer += dt;
        if (_stuckTimer > 2.0 && shouldScan) {
          debugPrint('[ERROR] Monster Stuck in tile $currentTile. State: $state. Target: $target. Forcing recovery.');

          // RECOVERY 1: Snap to current tile center to "un-snag" from corners
          parent.position = Vector2(
            currentTile.x * 32.0 + 16.0,
            currentTile.y * 32.0 + 16.0,
          );

          _stuckTimer = 0;

          // RECOVERY 2: If we have a path, nudge forward to the next waypoint
          if (currentPath.isNotEmpty && pathIndex < currentPath.length) {
            final nextWaypoint = currentPath[pathIndex].clone();
            debugPrint('[AI] Panic Nudge: Moving monster from ${parent.position} to next waypoint $nextWaypoint');
            parent.position = nextWaypoint;
            pathIndex++;
          } else {
            // RECOVERY 3: If no path or stuck even after pick, force a retreat to clear the area
            debugPrint('[AI] Stuck Recovery: No path found, forcing retreat to spawn.');
            state = MonsterState.retreating;
            target = null; // Clear target when retreating
            _calculatePathToSpawn();
          }
        }
      } else {
        _stuckTimer = 0;
        _lastTile = currentTile;
      }
    } else {

      _stuckTimer = 0;
      _lastTile = null;
    }
    
    _logThrottleTimer += dt;

    if (game.graceTimer.value > 0) {
      state = MonsterState.idle;
      currentPath = [];
      target = null;
      return;
    }

    // Handle Aggro Leashing
    if (_chaseTimer > 0) {
      _chaseTimer -= dt;
      if (_chaseTimer <= 0) {
        debugPrint('[AI] Aggro Leash expired. Returning to strategic target.');
        _pickNewTarget(); // This will prioritize the strategic target again
      }
    }

    if (shouldScan) {
      _checkProximityAggro();
      _updateSkills(dt);
    }

    switch (state) {
      case MonsterState.idle:
        _handleIdle(dt);
        break;
      case MonsterState.hunting:
        _handleHunting(dt);
        break;
      case MonsterState.attacking:
        _handleAttacking(dt, shouldScan: shouldScan);
        break;
      case MonsterState.retreating:
        _handleRetreating(dt);
        break;
    }
  }

  void _checkProximityAggro() {
    const double aggroRange = 192.0;
    BaseEntity? bestProxTarget;
    double bestDist = aggroRange;

    for (final ai in game.aiHunters) {
      if (ai.isDestroyed) continue;
      final d = parent.position.distanceTo(ai.position);
      if (d < bestDist) {
        bestDist = d;
        bestProxTarget = ai;
      }
    }

    final playerDist = parent.position.distanceTo(game.player.position);
    if (playerDist < bestDist && (bestProxTarget == null || playerDist < 64)) {
      bestProxTarget = game.player;
    }

    if (bestProxTarget != null && bestProxTarget != target) {
      bool canSwitch = false;

      if (state == MonsterState.idle) canSwitch = true;
      if (target is DoorEntity || target is BedEntity) {
         if (bestProxTarget is PlayerEntity) {
            if (playerDist < 96) canSwitch = true;
         } else {
            canSwitch = true;
         }
      }

      if (target is PlayerEntity || target is HunterAIEntity) {
         final currentDist = parent.position.distanceTo(target!.position);
         if (bestDist < currentDist * 0.5) canSwitch = true;
      }

      if (canSwitch) {
        target = bestProxTarget;

        // HARD LOCK: If we just aggroed a sleeping hunter, redirect to their door instead
        if (!_enforceDoorLock()) {
          state = MonsterState.hunting;
          _calculatePathToTarget();
        }

        _chaseTimer = maxChaseTime; // Start leashing
      }
    }
  }

  void _updateSkills(double dt) {
    _stunCooldownValue += dt;
    if (_stunCooldownValue >= stunCooldown) {
      const double areaStunRange = 96.0;
      final buildings = game.buildings
          .where((b) => b.center.distanceTo(parent.center) < areaStunRange)
          .toList();

      if (buildings.isNotEmpty) {
        bool shouldStun = false;
        
        // 1. Stun if any door in range is critical (<= 10% HP) to prevent last-second repairs
        for (final b in buildings) {
          if (b is DoorEntity && b.hp / b.maxHp <= 0.1) {
            shouldStun = true;
            debugPrint('[AI] Monster using Stun on critical door (${(b.hp/b.maxHp*100).toInt()}% HP)');
            break;
          }
        }

        // 2. Stun if target is being repaired (to disrupt)
        if (!shouldStun && target != null && target!.isBeingRepaired && parent.center.distanceTo(target!.center) < areaStunRange) {
          shouldStun = true;
        }

        // 3. Stun if any turrets are nearby (to disable)
        if (!shouldStun) {
          for (final b in buildings) {
            if (b is TurretEntity && !b.isStunned) {
              shouldStun = true;
              break;
            }
          }
        }

        if (shouldStun) {
          _stunCooldownValue = 0;
          parent.flashColor(Colors.purpleAccent);
          parent.pulse(1.4);
          for (final b in buildings) {
            b.stun(stunDuration);
          }
        }
      }
    }
  }

  bool _isRoomOccupied(String roomID) {
    if (roomID.isEmpty) return false;
    final bed = game.roomBeds[roomID];
    return bed?.isOccupied ?? false;
  }

  void _handleIdle(double dt) {
    decisionTimer += dt;
    if (decisionTimer >= 1.0) {
      decisionTimer = 0;
      _pickNewTarget();
    }
  }

  BaseEntity? _lastTarget;

  void _handleHunting(double dt) {
    if (target == null || target!.isDestroyed || !target!.isMounted) {
      _pickNewTarget();
      return;
    }

    if (_enforceDoorLock()) return;

    double dist = parent.center.distanceTo(target!.center);
    double attackDist = (target is DoorEntity) ? 48 : 64; 
    
    if (dist < attackDist) {
      bool hasLoS = game.hasLineOfSight(parent.center, target!.center);
      if (hasLoS) {
        bool canAttack = true;
        if (target is DoorEntity && !_isRoomOccupied((target as DoorEntity).roomID)) {
          canAttack = false;
        } else if (target is BedEntity && !(target as BedEntity).isOccupied) {
          canAttack = false;
        }

        if (canAttack) {
          state = MonsterState.attacking;
          currentPath = [];
          _frustrationTimer = 0;
          return;
        } else {
          _lastTarget = target;
          _pickNewTarget();
          return;
        }
      }
    }

    if (target is DoorEntity || target is BedEntity) {
      _frustrationTimer += dt;
      if (_frustrationTimer >= 15.0) {
        _lastTarget = target;
        _frustrationTimer = 0;
        _pickNewTarget();
        return;
      }
    } else {
      _frustrationTimer = 0;
    }

    if (parent.hp / parent.maxHp < 0.2) {
      state = MonsterState.retreating;
      target = null; // Clear target when retreating
      _calculatePathToSpawn();
      return;
    }

    if (currentPath.isEmpty || pathIndex >= currentPath.length) {
      if (dist < attackDist) {
        state = MonsterState.attacking;
        currentPath = [];
      } else {
        if (!_calculatePathToTarget()) {
          debugPrint('[ERROR] Path calculation failed during hunt. Picking new target.');
          _lastTarget = target;
          _pickNewTarget();
        }
      }
      return;
    }

    final waypoint = currentPath[pathIndex];
    final moveDist = parent.position.distanceTo(waypoint);

    if (moveDist < 8) {
      pathIndex++;
    } else {
      final direction = (waypoint - parent.position).normalized();
      final nextPosition = parent.position + direction * parent.speed * dt;
      final nextRect = Rect.fromLTWH(
        nextPosition.x - parent.size.x * 0.20,
        nextPosition.y - parent.size.y * 0.05,
        parent.size.x * 0.4,
        parent.size.y * 0.1,
      );

      final blockingEntity = game.getBlockingEntity(
        nextRect,
        ignoredEntities: (target is DoorEntity || target is BedEntity) ? [] : [target!],
      );

      if (blockingEntity != null && !blockingEntity.isDestroyed) {
        if (!(blockingEntity is DoorEntity && blockingEntity.isOpen)) {
          target = blockingEntity;
          state = MonsterState.attacking;
          currentPath = [];
          return;
        }
      }

      final currentTileX = (parent.position.x / 32).floor().clamp(0, DreamHunterGame.gridW - 1);
      final currentTileY = (parent.position.y / 32).floor().clamp(0, DreamHunterGame.gridH - 1);
      bool isCurrentlyInWall = game.wallGrid[currentTileX][currentTileY];

      if (!isCurrentlyInWall && game.isPositionBlocked(nextRect, ignoredEntities: [target!], targetPos: target!.position)) {
        final dx = nextPosition.x - parent.position.x;
        final dy = nextPosition.y - parent.position.y;
        bool blockedX = game.isPositionBlocked(nextRect.translate(dx, 0), ignoredEntities: [target!], targetPos: target!.position);
        bool blockedY = game.isPositionBlocked(nextRect.translate(0, dy), ignoredEntities: [target!], targetPos: target!.position);

        if (!blockedX || !blockedY) {
          if (!blockedX) parent.position.x = nextPosition.x;
          if (!blockedY) parent.position.y = nextPosition.y;
        } else {
          if (_logThrottleTimer > 1.0) {
            debugPrint('[ERROR] Monster blocked by wall at $nextPosition.');
            _logThrottleTimer = 0;
          }
          if (target != null && parent.center.distanceTo(target!.center) < 48) {
            state = MonsterState.attacking;
            currentPath = [];
            return;
          }
          return;
        }
      } else {
        parent.position = nextPosition;
      }

      parent.updateSprite(direction);
    }
  }

  void _handleAttacking(double dt, {bool shouldScan = false}) {
    if (target == null || target!.isDestroyed || !target!.isMounted) {
      _pickNewTarget();
      return;
    }

    if (_enforceDoorLock()) return;

    if (target is PlayerEntity) {
      _playerTargetingTimer += dt;
      if (_playerTargetingTimer < 1.0) return; 
    } else {
      _playerTargetingTimer = 0;
    }

    double dist = parent.center.distanceTo(target!.center);
    if (!game.hasLineOfSight(parent.center, target!.center)) {
      state = MonsterState.hunting;
      return;
    }

    if (parent.hp / parent.maxHp < 0.2) {
      state = MonsterState.retreating;
      target = null; // Clear target when retreating
      _calculatePathToSpawn();
      return;
    }

    double maxDist = (target is DoorEntity) ? 60 : 72;
    if (dist > maxDist) {
      state = MonsterState.hunting;
      _frustrationTimer = 0;
      return;
    }

    if (target is DoorEntity || target is BedEntity) {
      _frustrationTimer += dt;
      if (_frustrationTimer >= 20.0) {
        _lastTarget = target;
        _frustrationTimer = 0;
        _pickNewTarget();
        return;
      }
    } else {
      _frustrationTimer = 0;
    }

    attackTimer += dt;
    if (attackTimer >= 1.0) {
      attackTimer = 0;
      _performAttack();
    }
  }

  void _handleRetreating(double dt) {
    bool atSpawn = false;
    for (final spawn in game.monsterSpawnPoints) {
      if (parent.position.distanceTo(spawn) < 20) {
        atSpawn = true;
        break;
      }
    }

    if (atSpawn) {
      parent.hp = (parent.hp + parent.maxHp * 0.05 * dt).clamp(0, parent.maxHp);
      if (parent.hp >= parent.maxHp * 0.7 && parent.hp < parent.maxHp) {
        game.world.add(FloatingFeedback(label: '!', color: Colors.redAccent, position: parent.position + Vector2(0, -parent.size.y), icon: Icons.priority_high_rounded));
        parent.flashColor(Colors.redAccent);
        _pickNewTarget();
        return;
      }
      if (parent.hp == parent.maxHp) _pickNewTarget();
    } else {
      if (currentPath.isEmpty || pathIndex >= currentPath.length) {
        _calculatePathToSpawn();
        return;
      }
      final waypoint = currentPath[pathIndex];
      final moveDist = parent.position.distanceTo(waypoint);
      
      if (moveDist < 4) {
        pathIndex++;
      } else {
        final direction = (waypoint - parent.position).normalized();
        final nextPosition = parent.position + direction * parent.speed * dt;

        // Retreating has a slightly more "forgiving" hitbox to ensure it can get out
        final nextRect = Rect.fromLTWH(
          nextPosition.x - parent.size.x * 0.15,
          nextPosition.y - parent.size.y * 0.05,
          parent.size.x * 0.3,
          parent.size.y * 0.1,
        );

        // ATTACK BLOCKS: If a door is closed in our path while retreating, attack it!
        final blockingEntity = game.getBlockingEntity(
          nextRect,
          ignoredEntities: [],
        );
        if (blockingEntity != null && !blockingEntity.isDestroyed) {
          if (!(blockingEntity is DoorEntity && blockingEntity.isOpen)) {
            target = blockingEntity;
            state = MonsterState.attacking;
            currentPath = [];
            return;
          }
        }

        final currentTileX =
            (parent.position.x / 32).floor().clamp(0, DreamHunterGame.gridW - 1);
        final currentTileY =
            (parent.position.y / 32).floor().clamp(0, DreamHunterGame.gridH - 1);
        bool isCurrentlyInWall = game.wallGrid[currentTileX][currentTileY];

        // Collision check (only if not already in a wall)
        if (!isCurrentlyInWall && game.isPositionBlocked(nextRect)) {
           // If blocked while retreating, just nudge slowly or try to slide
           final dx = nextPosition.x - parent.position.x;
           final dy = nextPosition.y - parent.position.y;
           bool blockedX = game.isPositionBlocked(nextRect.translate(dx, 0));
           bool blockedY = game.isPositionBlocked(nextRect.translate(0, dy));

           if (!blockedX || !blockedY) {
             if (!blockedX) parent.position.x = nextPosition.x;
             if (!blockedY) parent.position.y = nextPosition.y;
           }
           // If fully blocked, the stuck detection in update() will handle it via teleport
        } else {
          parent.position = nextPosition;
        }
        
        parent.updateSprite(direction);
      }
    }
  }

  void _pickNewTarget() {
    _chaseTimer = 0; // Reset aggro leash when picking a new strategic target
    final bestTargetIDs = MatchManager.instance.getBestTargets(parent.position);
    if (bestTargetIDs.isEmpty) {
      state = MonsterState.idle;
      target = null;
      return;
    }

    // Try to keep current strategic target if it's still viable and has high score
    // (Implicitly handled by getBestTargets returning it at the top)

    for (final id in bestTargetIDs) {
      final buildings = game.getBuildingsInRoom(id);
      if (buildings.isNotEmpty) {
        final door = buildings.whereType<DoorEntity>().firstOrNull;
        if (door != null && !door.isDestroyed) {
          // If door exists and is intact, it MUST be the target for this room
          target = door;
          state = MonsterState.hunting;
          if (_calculatePathToTarget()) return;
          continue; // If pathing failed, try next room instead of targeting bed
        }

        final bed = buildings.whereType<BedEntity>().firstOrNull;
        if (bed != null && !bed.isDestroyed && bed != _lastTarget) {
          target = bed;
          state = MonsterState.hunting;
          if (_calculatePathToTarget()) return;
        }
      }
    }

    if (_lastTarget != null) {
      _lastTarget = null;
      _pickNewTarget();
      return;
    }
    state = MonsterState.idle;
    target = null;
  }

  bool _calculatePathToTarget() {
    if (target == null) return false;
    final path = game.getShortestPath(parent.position, target!.position);
    if (path.isEmpty) return false;
    currentPath = path;
    pathIndex = 0;
    return true;
  }

  void _calculatePathToSpawn() {
    Vector2? nearestSpawn;
    double minDist = double.infinity;
    for (final spawn in game.monsterSpawnPoints) {
      final d = parent.position.distanceTo(spawn);
      if (d < minDist) {
        minDist = d;
        nearestSpawn = spawn;
      }
    }
    if (nearestSpawn != null) {
      currentPath = game.getShortestPath(parent.position, nearestSpawn);
      pathIndex = 0;
    }
  }

  void _performAttack() {
    if (target == null || target!.isDestroyed || !target!.isMounted) {
      _pickNewTarget();
      return;
    }

    if (_enforceDoorLock()) return;

    final dist = parent.center.distanceTo(target!.center);
    final maxDist = (target is DoorEntity) ? 64.0 : 68.0; 
    if (dist > maxDist || !game.hasLineOfSight(parent.center, target!.center)) {
      state = MonsterState.hunting;
      _calculatePathToTarget();
      return;
    }

    parent.pulse(1.4);
    final bool wasDestroyedBefore = target!.isDestroyed;
    target!.takeDamage(parent.attackDamage);

    if (target is PlayerEntity || target is HunterAIEntity) {
      if (target!.hp <= 0) {
        final roomID = target!.roomID;
        if (roomID.isNotEmpty) {
          game.roomFog[roomID]?.markDeath();
        }
      }
    }

    if (target is DoorEntity && !wasDestroyedBefore && target!.isDestroyed) {
      final bed = game.roomBeds[(target as DoorEntity).roomID];
      if (bed != null && !bed.isDestroyed) {
        target = bed;
        state = MonsterState.hunting;
        _calculatePathToTarget();
        return;
      }
    }

    if (target is BedEntity && !wasDestroyedBefore && target!.isDestroyed) {
      final bed = target as BedEntity;
      if (bed.owner != null && !bed.owner!.isDestroyed) {
        bed.owner!.takeDamage(1000.0);
      }
      _escapeRoomAfterKill();
      return;
    }

    if (target is DoorEntity || target is BedEntity) {
      final roomID = (target is DoorEntity) ? (target as DoorEntity).roomID : (target as BedEntity).roomID;
      final bed = game.roomBeds[roomID];
      if (bed != null && bed.isOccupied && bed.owner?.hunterIndex != null) {
        MatchManager.instance.setHunterUnderAttack(bed.owner!.hunterIndex!);
      }
    } else if (target!.hunterIndex != null) {
      MatchManager.instance.setHunterUnderAttack(target!.hunterIndex!);
    }

    if ((target is PlayerEntity || target is HunterAIEntity) && !wasDestroyedBefore && target!.isDestroyed) {
      _escapeRoomAfterKill();
      return;
    }

    if (target is DoorEntity) {
      final door = target as DoorEntity;
      final double xpGained = (parent.attackDamage / door.maxHp) * 100;
      final double bonusXP = (!wasDestroyedBefore && door.isDestroyed) ? 20.0 : 0.0;
      parent.gainExperience((xpGained + bonusXP).floor());
    }
  }

  void _escapeRoomAfterKill() {
    final doors = game.getBuildings().whereType<DoorEntity>().where((d) => !d.isDestroyed);
    if (doors.isEmpty) {
      _pickNewTarget();
      return;
    }

    DoorEntity? exitDoor;
    double minDist = 300;
    for (final door in doors) {
      final d = parent.position.distanceTo(door.position);
      if (d < minDist) {
        minDist = d;
        exitDoor = door;
      }
    }

    if (exitDoor != null) {
      target = exitDoor;
      state = MonsterState.hunting;
      _calculatePathToTarget();
    } else {
      _pickNewTarget();
    }
  }

  /// Finds the DoorEntity associated with a roomID.
  DoorEntity? _getRoomDoor(String roomID) {
    if (roomID.isEmpty) return null;
    return game
        .getBuildingsInRoom(roomID)
        .whereType<DoorEntity>()
        .where((d) => !d.isDestroyed)
        .firstOrNull;
  }

  /// HARD LOCK: Prevents attacking a bed or sleeping hunter if the door is intact.
  /// Returns true if the target was redirected to the door.
  bool _enforceDoorLock() {
    if (target == null) return false;

    // A target is "protected" if it's a bed or a sleeping hunter
    bool isProtected = (target is BedEntity) || (target!.isSleeping);
    if (!isProtected) return false;

    final roomID = target!.roomID;
    final door = _getRoomDoor(roomID);

    if (door != null) {
      // Door exists and is not destroyed! Force redirection to door.
      if (target != door) {
        debugPrint(
            '[AI] Hard Lock: Redirecting monster from ${target.runtimeType} to Door of room $roomID');
        target = door;
        state = MonsterState.hunting;
        _calculatePathToTarget();
        return true;
      }
    }
    return false;
  }
}

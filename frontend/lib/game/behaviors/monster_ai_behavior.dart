import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:dreamhunter/game/entities/monster_entity.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/entities/door_entity.dart';
import 'package:dreamhunter/game/entities/bed_entity.dart';
import 'package:dreamhunter/game/entities/turret_entity.dart';
import 'package:dreamhunter/game/entities/player_entity.dart';
import 'package:dreamhunter/game/entities/hunter_ai_entity.dart';
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
  double stunTimer = 0;
  double healAggressionTimer = 0;
  double _scanThrottleTimer = 0;

  double _frustrationTimer = 0;
  BaseEntity? _lastFrustratedTarget;
  
  double _lastTargetHp = 0;
  double _surpriseTimer = 0;

  final double stunCooldown = 15.0;
  final double stunDuration = 3.0;
  final double stunRange = 64.0;

  double _stuckTimer = 0;
  final Vector2 _lastPosition = Vector2.zero();

  @override
  void update(double dt) {
    super.update(dt);

    if (parent.isDestroyed) return;

    // Throttle expensive checks (aggro, skills, path recalculation) to 5Hz
    _scanThrottleTimer += dt;
    bool shouldScan = false;
    if (_scanThrottleTimer >= 0.2) {
      _scanThrottleTimer = 0;
      shouldScan = true;
    }

    // Anti-Glitch: Check if making progress
    if (state == MonsterState.hunting || state == MonsterState.attacking) {
      if (parent.position.distanceTo(_lastPosition) < 0.5) {
        _stuckTimer += dt;
        if (_stuckTimer > 1.5) {
          // Stuck for 1.5 seconds
          _stuckTimer = 0;
          if (shouldScan) _pickNewTarget(); // Force re-evaluation only on scan frames
        }
      } else {
        _stuckTimer = 0;
      }
      _lastPosition.setFrom(parent.position);
    }

    // 0. Grace Period Check: Don't move or act until grace timer is 0
    if (game.graceTimer.value > 0) {
      state = MonsterState.idle;
      currentPath = [];
      target = null;
      return;
    }

    // Expensive logic throttled to 5Hz
    if (shouldScan) {
      _checkProximityAggro();
      _updateSkills(dt);
    }

    // 2. State Machine (Movement and simple attack timers remain at full FPS)
    switch (state) {
      case MonsterState.idle:
        _handleIdle(dt);
        break;
      case MonsterState.hunting:
        _handleHunting(dt);
        break;
      case MonsterState.attacking:
        _handleAttacking(dt);
        break;
      case MonsterState.retreating:
        _handleRetreating(dt);
        break;
    }
  }

  void _checkProximityAggro() {
    // 6 tiles * 32px = 192px
    const double aggroRange = 192.0;

    bool isInsideTargetRoom(BaseEntity entity) {
      if (target is DoorEntity) {
        return entity.roomID == (target as DoorEntity).roomID;
      }
      if (target is BedEntity) {
        return entity.roomID == (target as BedEntity).roomID;
      }
      return false;
    }

    bool isBusyInRoom = target is DoorEntity || target is BedEntity;
    bool isHuntingHuman = target is PlayerEntity;
    bool isOccupiedWithAI = target is HunterAIEntity;

    void tryAggro(BaseEntity entity) {
      if (entity.isDestroyed) return;
      final dist = parent.position.distanceTo(entity.position);
      
      if (dist < aggroRange) {
        if (target == entity) return;
        if (isInsideTargetRoom(entity)) return;

        // Simplified aggro logic (No reactive proximity)
        if ((isOccupiedWithAI || isBusyInRoom) && math.Random().nextDouble() < 0.85) return;
        if (entity.isSleeping && (isHuntingHuman || isOccupiedWithAI || isBusyInRoom)) return;

        target = entity;
        state = MonsterState.hunting;
        _calculatePathToTarget();
      }
    }

    tryAggro(game.player);
    for (final ai in game.aiHunters) {
      tryAggro(ai);
    }
  }

  void _updateSkills(double dt) {
    stunTimer += dt;
    if (stunTimer >= stunCooldown) {
      // STRATEGIC AREA STUN: Disable buildings and repairs in a 3-tile radius
      const double areaStunRange = 96.0; 
      
      final buildings = game.getBuildings()
          .where((b) => b.position.distanceTo(parent.position) < areaStunRange);

      if (buildings.isNotEmpty) {
        stunTimer = 0;
        // Visual feedback for area stun
        parent.add(
          ColorEffect(
            Colors.purpleAccent,
            EffectController(duration: 0.2, reverseDuration: 0.2),
            opacityTo: 0.5,
          ),
        );

        for (final b in buildings) {
          if (b is TurretEntity) {
            b.stun(stunDuration);
          }
          // Disable repairs for everyone in range
          b.isBeingRepaired = false;
        }
      }
    }
  }

  bool _isRoomOccupied(String roomID) {
    if (roomID.isEmpty) return false;
    // Optimized: Use roomBeds Map for O(1) lookup
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

  void _handleHunting(double dt) {
    if (target == null ||
        target!.isDestroyed ||
        (target is DoorEntity &&
            !_isRoomOccupied((target as DoorEntity).roomID)) ||
        (target is BedEntity && !(target as BedEntity).isOccupied)) {
      _pickNewTarget();
      return;
    }

    // Proximity check: Force the monster to be right next to the target
    // Using centers to be anchor-agnostic and more precise
    double dist = parent.center.distanceTo(target!.center);
    // Increased thresholds to account for bed size vs ghost center
    // Door range increased to 48 to allow attacking from hallway centers
    double attackDist = (target is DoorEntity) ? 48 : 52;
    if (dist < attackDist) {
      state = MonsterState.attacking;
      currentPath = [];
      return;
    }

    // Health check for retreat
    if (parent.hp / parent.maxHp < 0.2) {
      state = MonsterState.retreating;
      _calculatePathToSpawn();
      return;
    }

    if (currentPath.isEmpty || pathIndex >= currentPath.length) {
      if (parent.center.distanceTo(target!.center) < 56) {
        state = MonsterState.attacking;
      } else {
        _calculatePathToTarget();
      }
      return;
    }

    // Move along path
    final waypoint = currentPath[pathIndex];
    final moveDist = parent.position.distanceTo(waypoint);

    if (moveDist < 4) {
      pathIndex++;
    } else {
      final direction = (waypoint - parent.position).normalized();
      final nextPosition = parent.position + direction * parent.speed * dt;

      // Performance Optimized: Dynamic Building Collision Check
      // Using a thinner hitbox (30% width) to ensure we can fit through 32px doors easily
      final nextRect = Rect.fromLTWH(
        nextPosition.x - parent.size.x * 0.15,
        nextPosition.y - parent.size.y * 0.05,
        parent.size.x * 0.3,
        parent.size.y * 0.1,
      );

      // DYNAMIC SMASHING: Smash through breakable buildings in path
      // REFINED: Only happens if we are already inside a room heading for the BED.
      final blockingEntity = game.getBlockingEntity(
        nextRect,
        ignoredEntities: [target!],
      );
      if (blockingEntity != null && target is BedEntity) {
        // Switch to attacking the obstacle immediately
        target = blockingEntity;
        state = MonsterState.attacking;
        currentPath = [];
        return;
      }

      // 2. Check for Unbreakables (Static Walls)
      if (game.isPositionBlocked(nextRect, ignoredEntities: [target!])) {
        // Stop and attack if target is within reach (precise center check)
        if (target != null && parent.center.distanceTo(target!.center) < 48) {
          state = MonsterState.attacking;
          currentPath = [];
          return;
        }

        // FIND ANOTHER PATH: We hit a wall.
        // Recalculate shortest path immediately to find a way around.
        _calculatePathToTarget();
        return;
      }

      // 3. Clear Path: Move forward
      parent.position = nextPosition;
      parent.updateSprite(direction);
    }
  }

  void _handleAttacking(double dt) {
    if (target == null || target!.isDestroyed) {
      _pickNewTarget();
      return;
    }

    // Health check for retreat (Ensure monster retreats if taking too much damage mid-fight)
    if (parent.hp / parent.maxHp < 0.2) {
      state = MonsterState.retreating;
      _healAccumulator = 0;
      _calculatePathToSpawn();
      return;
    }

    // NEW: Surprise Check (Did the target just upgrade/heal?)
    if (target!.hp > _lastTargetHp + 1.0) {
      // SURPRISE! The monster is confused by the sudden repair.
      _surpriseTimer = 3.0; // Retreat for 3 seconds
      state = MonsterState.retreating;
      _calculatePathToSpawn(); // Retreat towards spawn
      _lastTargetHp = target!.hp;
      return;
    }
    _lastTargetHp = target!.hp;

    // Must stay close to keep attacking
    double dist = parent.center.distanceTo(target!.center);
    // MaxDist must be larger than attackDist to prevent jitter
    double maxDist = (target is DoorEntity) ? 60 : 64;
    if (dist > maxDist) {
      state = MonsterState.hunting;
      _frustrationTimer = 0; // Reset frustration if we lose contact
      return;
    }

    // NEW: Frustration Mechanic (Anti-Stall)
    // If we are hitting a Door or Bed for more than 15 seconds, we give up and find someone else.
    if (target is DoorEntity || target is BedEntity) {
      _frustrationTimer += dt;
      if (_frustrationTimer >= 15.0) {
        _lastFrustratedTarget = target;
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

  double _healAccumulator = 0;

  void _handleRetreating(double dt) {
    // Handle Surprise Retreat Cooldown
    if (_surpriseTimer > 0) {
      _surpriseTimer -= dt;
      if (_surpriseTimer <= 0) {
        // If we are still healthy, go back to hunting. Otherwise, keep retreating.
        if (parent.hp / parent.maxHp >= 0.2) {
          _pickNewTarget();
          return;
        }
      }
    }

    // Healing at spawn
    bool atSpawn = false;
    for (final spawn in game.monsterSpawnPoints) {
      if (parent.position.distanceTo(spawn) < 16) {
        atSpawn = true;
        break;
      }
    }

    if (atSpawn) {
      final double healAmount = parent.maxHp * 0.05 * dt; // 5% per second at spawn
      parent.hp = (parent.hp + healAmount).clamp(0, parent.maxHp);
      
      _healAccumulator += healAmount;
      final double tenPercent = parent.maxHp * 0.1;
      
      // Every 10% healed, 50% chance to attack again
      if (_healAccumulator >= tenPercent) {
        _healAccumulator -= tenPercent;
        if (math.Random().nextDouble() < 0.5) {
          _pickNewTarget();
          return;
        }
      }

      if (parent.hp == parent.maxHp) {
        _pickNewTarget();
      }
    } else {
      // Move to spawn
      if (currentPath.isEmpty || pathIndex >= currentPath.length) {
        _calculatePathToSpawn();
        return;
      }

      final waypoint = currentPath[pathIndex];
      final dist = parent.position.distanceTo(waypoint);
      if (dist < 4) {
        pathIndex++;
      } else {
        final direction = (waypoint - parent.position).normalized();
        parent.position += direction * parent.speed * dt;
        parent.updateSprite(direction);
      }
    }
  }

  void _pickNewTarget() {
    // STRATEGIC REFACTOR: Use the Target Registry instead of scanning the map.
    final bestTargetIDs = MatchManager.instance.getBestTargets();
    
    if (bestTargetIDs.isEmpty) {
      state = MonsterState.idle;
      target = null;
      return;
    }

    // Find the first target from the registry that exists in the world
    for (final id in bestTargetIDs) {
      // Find door or bed in this room
      final buildings = game.getBuildingsInRoom(id);
      if (buildings.isNotEmpty) {
        // Prefer Door if not destroyed
        final door = buildings.whereType<DoorEntity>().firstOrNull;
        if (door != null && !door.isDestroyed) {
          target = door;
          state = MonsterState.hunting;
          _calculatePathToTarget();
          return;
        }

        final bed = buildings.whereType<BedEntity>().firstOrNull;
        if (bed != null && !bed.isDestroyed) {
          target = bed;
          state = MonsterState.hunting;
          _calculatePathToTarget();
          return;
        }
      }
    }

    state = MonsterState.idle;
    target = null;
  }

  void _calculatePathToTarget() {
    if (target == null) return;
    currentPath = game.getShortestPath(parent.position, target!.position);
    pathIndex = 0;
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
    if (target == null) return;

    // Visual pulse: More dramatic and visible
    parent.add(
      ScaleEffect.to(
        Vector2.all(1.4),
        EffectController(duration: 0.15, reverseDuration: 0.15),
      ),
    );

    final double damage = parent.attackDamage;
    final bool wasDestroyedBefore = target!.isDestroyed;

    target!.takeDamage(damage);

    // NEW: Notify HUD if target is a room building (Door/Bed)
    if (target is DoorEntity || target is BedEntity) {
      final roomID = (target is DoorEntity)
          ? (target as DoorEntity).roomID
          : (target as BedEntity).roomID;

      // Optimized: Use roomBeds Map for O(1) lookup
      final bed = game.roomBeds[roomID];

      if (bed != null && bed.isOccupied && bed.owner?.hunterIndex != null) {
        MatchManager.instance.setHunterUnderAttack(bed.owner!.hunterIndex!);
      }
    } else if (target!.hasCategory('player') || target!.hasCategory('ai_hunter')) {
      if (target!.hunterIndex != null) {
        MatchManager.instance.setHunterUnderAttack(target!.hunterIndex!);
      }
    }

    // If target was a Hunter and just died, check if we need to escape a room
    if ((target is PlayerEntity || target is HunterAIEntity) &&
        !wasDestroyedBefore &&
        target!.isDestroyed) {
      _escapeRoomAfterKill();
      return;
    }

    // XP Logic: Only Doors give XP (Beds do NOT give XP)
    if (target is DoorEntity) {
      final door = target as DoorEntity;
      // 1 XP for every 1% of max HP removed
      final double xpGained = (damage / door.maxHp) * 100;

      // Bonus XP for destruction
      final double bonusXP = (!wasDestroyedBefore && door.isDestroyed)
          ? 20.0
          : 0.0;

      parent.gainExperience((xpGained + bonusXP).floor());
    }

    // NEW: Kill sleeping hunter if bed is destroyed
    if (target is BedEntity && !wasDestroyedBefore && target!.isDestroyed) {
      final bed = target as BedEntity;
      if (bed.owner != null && !bed.owner!.isDestroyed) {
        bed.owner!.takeDamage(1000.0); // Kill the sleeper
      }
    }
  }

  void _escapeRoomAfterKill() {
    // We just killed a hunter. If we are in a room, we need to smash the door to get out.
    // PERFORMANCE OPTIMIZATION: Use cached _buildings list
    final doors = game.getBuildings().whereType<DoorEntity>().where(
      (d) => !d.isDestroyed,
    );
    if (doors.isEmpty) {
      _pickNewTarget();
      return;
    }

    // Find the closest door. If it's very close, it's likely the door to the room we are in.
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
}

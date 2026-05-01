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

    // Anti-Glitch: Check if making progress
    if (state == MonsterState.hunting || state == MonsterState.attacking) {
      if (parent.position.distanceTo(_lastPosition) < 0.5) {
        _stuckTimer += dt;
        if (_stuckTimer > 1.5) {
          // Stuck for 1.5 seconds
          _stuckTimer = 0;
          _pickNewTarget(); // Force re-evaluation
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

    // New: Proximity Aggro Check (6 tiles = 192px)
    // If a hunter is nearby, they become the primary target.
    _checkProximityAggro();

    // 1. Skill Management (Stun)
    _updateSkills(dt);

    // 2. State Machine
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

    // Smart Jitter Fix: If we are attacking/hunting a Door/Bed,
    // ignore proximity aggro ONLY if the entity is inside that same room.
    // This allows us to still notice people running past in the hallway.
    bool isInsideTargetRoom(BaseEntity entity) {
      if (target is DoorEntity) {
        return entity.roomID == (target as DoorEntity).roomID;
      }
      if (target is BedEntity) {
        return entity.roomID == (target as BedEntity).roomID;
      }
      return false;
    }

    // RULE: If we are already hunting a hunter,
    // don't let proximity aggro jitter our target unless the new one is "better".
    bool isHuntingHuman = target is PlayerEntity;
    bool isOccupiedWithAI = target is HunterAIEntity;

    // Check Player
    if (!game.player.isDestroyed) {
      if (parent.position.distanceTo(game.player.position) < aggroRange) {
        if (target == game.player) return;

        // Smart Jitter Fix
        if (isInsideTargetRoom(game.player)) return;

        // NEW DECISION LOGIC: 75% chance to ignore human aggro if we are already busy
        // with an AI hunter or just "don't feel like it" right now.
        if (isOccupiedWithAI && math.Random().nextDouble() < 0.75) {
          return;
        }

        // If the player is sleeping, only aggro if we are idle or hunting something low-value.
        if (game.player.isSleeping && (isHuntingHuman || isOccupiedWithAI)) {
          return;
        }

        target = game.player;
        state = MonsterState.hunting;
        _calculatePathToTarget();
        return;
      }
    }

    // Check AI Hunters
    for (final ai in game.aiHunters) {
      if (!ai.isDestroyed) {
        if (parent.position.distanceTo(ai.position) < aggroRange) {
          if (target == ai) return;

          // Smart Jitter Fix
          if (isInsideTargetRoom(ai)) continue;

          if (ai.isSleeping && (isHuntingHuman || isOccupiedWithAI)) {
            continue;
          }

          target = ai;
          state = MonsterState.hunting;
          _calculatePathToTarget();
          return;
        }
      }
    }
  }

  void _updateSkills(double dt) {
    stunTimer += dt;
    if (stunTimer >= stunCooldown) {
      // Only stun turrets in occupied rooms
      final turrets = game.world.children
          .whereType<TurretEntity>()
          .where((t) => t.position.distanceTo(parent.position) < stunRange)
          .where((t) => _isRoomOccupied(t.roomID));

      if (turrets.isNotEmpty) {
        stunTimer = 0;
        for (final turret in turrets) {
          turret.stun(stunDuration);
        }
      }
    }
  }

  bool _isRoomOccupied(String roomID) {
    if (roomID.isEmpty) return false;
    // Find the bed for this room and check occupancy
    final bed = game.world.children
        .whereType<BedEntity>()
        .where((b) => b.roomID == roomID)
        .firstOrNull;

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
    double attackDist = (target is DoorEntity) ? 32 : 40;
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
      if (parent.center.distanceTo(target!.center) < 44) {
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

      // 1. Check for Breakables (Buildings/Doors)
      // We ignore our CURRENT target so we can walk "into" its attack range
      final blockingEntity = game.getBlockingEntity(
        nextRect,
        ignoredEntities: [target!],
      );
      if (blockingEntity != null) {
        // SMASH THROUGH: The path is blocked by a breakable object.
        // Change target to the obstacle and start hunting/attacking it.
        target = blockingEntity;
        state = MonsterState.hunting;
        _calculatePathToTarget();
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
    double maxDist = (target is DoorEntity) ? 44 : 52;
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

  void _handleRetreating(double dt) {
    // NEW: Handle Surprise Retreat
    if (_surpriseTimer > 0) {
      _surpriseTimer -= dt;
      if (_surpriseTimer <= 0) {
        _pickNewTarget();
        return;
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
      parent.hp = (parent.hp + parent.maxHp * 0.01 * dt).clamp(0, parent.maxHp);

      healAggressionTimer += dt;
      if (healAggressionTimer >= 10.0) {
        // Every 10 seconds of healing
        healAggressionTimer = 0;
        // 25% chance to be "Brave" and stop retreating
        if (math.Random().nextDouble() < 0.25) {
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
    final potentialTargets = <BaseEntity>[];

    // 1. Hunters (Prioritize active ones, but include sleeping ones)
    final activeAIHunters = <HunterAIEntity>[];
    final sleepingAIHunters = <HunterAIEntity>[];
    PlayerEntity? humanPlayer;

    if (!game.player.isDestroyed) {
      humanPlayer = game.player;
    }

    for (final ai in game.aiHunters) {
      if (!ai.isDestroyed) {
        if (ai.isSleeping) {
          sleepingAIHunters.add(ai);
        } else {
          activeAIHunters.add(ai);
        }
      }
    }

    // NEW: Phase-Based AI Bias (Fairness Scaling)
    double aiBias = 0.75;
    final remainingSeconds = game.matchTimer.value;
    if (remainingSeconds > 720) {
      // Phase 1 (15m to 12m): 95% AI Bias (Mercy for Player)
      aiBias = 0.95;
    } else if (remainingSeconds > 300) {
      // Phase 2 (12m to 5m): 75% AI Bias (Standard)
      aiBias = 0.75;
    } else {
      // Phase 3 (5m to 0m): 50% AI Bias (Late-game ruthless)
      aiBias = 0.50;
    }

    final bool preferAI = math.Random().nextDouble() < aiBias;

    // 2. Doors of occupied rooms
    final occupiedDoors = game.world.children
        .whereType<DoorEntity>()
        .where((d) => !d.isDestroyed && _isRoomOccupied(d.roomID))
        .toList();

    // 3. Occupied beds
    final occupiedBeds = game.world.children
        .whereType<BedEntity>()
        .where((b) => !b.isDestroyed && b.isOccupied)
        .toList();

    potentialTargets.addAll(activeAIHunters);
    if (humanPlayer != null && !humanPlayer.isSleeping) {
      potentialTargets.add(humanPlayer);
    }
    potentialTargets.addAll(occupiedDoors);
    potentialTargets.addAll(occupiedBeds);
    potentialTargets.addAll(sleepingAIHunters);
    if (humanPlayer != null && humanPlayer.isSleeping) {
      potentialTargets.add(humanPlayer);
    }

    if (potentialTargets.isEmpty) {
      state = MonsterState.idle;
      target = null;
      return;
    }

    // Sort with Weighting
    potentialTargets.sort((a, b) {
      final distA = parent.position.distanceTo(a.position);
      final distB = parent.position.distanceTo(b.position);

      double scoreA = distA;
      double scoreB = distB;

      // Penalty for sleeping (500px)
      if (a is HunterAIEntity && a.isSleeping) scoreA += 500;
      if (b is HunterAIEntity && b.isSleeping) scoreB += 500;
      if (a is PlayerEntity && a.isSleeping) scoreA += 500;
      if (b is PlayerEntity && b.isSleeping) scoreB += 500;

      // Weighting Bias
      if (preferAI) {
        // If we prefer AI, give Human Player a "distance penalty" (800px)
        if (a is PlayerEntity) scoreA += 800;
        if (b is PlayerEntity) scoreB += 800;
      } else {
        // If we prefer Human, give AI Hunters a "distance penalty" (800px)
        if (a is HunterAIEntity) scoreA += 800;
        if (b is HunterAIEntity) scoreB += 800;
      }

      // NEW: Frustration Penalty (+2000px)
      if (a == _lastFrustratedTarget) scoreA += 2000;
      if (b == _lastFrustratedTarget) scoreB += 2000;

      // NEW: Level-Based Priority
      // Each level adds 100 to the score (making it less attractive)
      // Level 1: +100, Level 5: +500
      scoreA += a.entityLevel * 100;
      scoreB += b.entityLevel * 100;

      return scoreA.compareTo(scoreB);
    });

    final newTarget = potentialTargets.first;

    // Reset frustration if we actually switched to something else
    if (newTarget != _lastFrustratedTarget) {
      _lastFrustratedTarget = null;
    }

    target = newTarget;
    _lastTargetHp = target?.hp ?? 0;
    state = MonsterState.hunting;
    _calculatePathToTarget();
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

    // If target was a Hunter and just died, check if we need to escape a room
    if ((target is PlayerEntity || target is HunterAIEntity) &&
        !wasDestroyedBefore &&
        target!.isDestroyed) {
      _escapeRoomAfterKill();
      return;
    }

    // XP Logic: Only Doors give XP
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
  }

  void _escapeRoomAfterKill() {
    // We just killed a hunter. If we are in a room, we need to smash the door to get out.
    final doors = game.world.children.whereType<DoorEntity>().where(
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

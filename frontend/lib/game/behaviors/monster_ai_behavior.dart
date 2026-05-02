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
  double healAggressionTimer = 0;
  double _scanThrottleTimer = 0;

  double _frustrationTimer = 0;
  
  double _lastTargetHp = 0;
  double _surpriseTimer = 0;
  bool _hasBeenSurprised = false;

  final double stunCooldown = 10.0;
  final double stunDuration = 5.0;
  final double stunRange = 64.0;

  double _stuckTimer = 0;
  double _logThrottleTimer = 0;
  double _playerTargetingTimer = 0;
  math.Point<int>? _lastTile;

  @override
  void update(double dt) {
    super.update(dt);

    if (parent.isDestroyed) return;

    // Throttle expensive checks (aggro, skills, path recalculation) to 4Hz
    _scanThrottleTimer += dt;
    bool shouldScan = false;
    if (_scanThrottleTimer >= 0.25) {
      _scanThrottleTimer = 0;
      shouldScan = true;
    }

    // Anti-Glitch: Check if making progress (Based on Tile movement)
    // We only check for stuckness while hunting or retreating. 
    // Attacking is intentionally stationary.
    if (state == MonsterState.hunting || state == MonsterState.retreating) {
      final currentTile = math.Point(
        (parent.position.x / 32).floor(),
        (parent.position.y / 32).floor(),
      );

      if (currentTile == _lastTile) {
        _stuckTimer += dt;
        if (_stuckTimer > 2.0 && shouldScan) {
          // Stuck for 2 seconds, re-evaluate only on scan frame
          debugPrint(
            '[MONSTER] Stuck in tile $currentTile. Forcing target re-evaluation.',
          );
          _stuckTimer = 0;
          _pickNewTarget(); // Force re-evaluation
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

    // 0. Grace Period Check: Don't move or act until grace timer is 0
    if (game.graceTimer.value > 0) {
      state = MonsterState.idle;
      currentPath = [];
      target = null;
      return;
    }

    // Expensive logic throttled to 4Hz
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
        _handleAttacking(dt, shouldScan: shouldScan);
        break;
      case MonsterState.retreating:
        _handleRetreating(dt);
        break;
    }
  }

  void _checkProximityAggro() {
    // 6 tiles * 32px = 192px
    const double aggroRange = 192.0;

    // FIND BEST PROXIMITY TARGET
    // Priority: 1. AI Hunter (Easy/Standard prey) 2. Player (Boss prey)
    BaseEntity? bestProxTarget;
    double bestDist = aggroRange;

    // 1. Check AI Hunters first (Top priority)
    for (final ai in game.aiHunters) {
      if (ai.isDestroyed) continue;
      final d = parent.position.distanceTo(ai.position);
      if (d < bestDist) {
        bestDist = d;
        bestProxTarget = ai;
      }
    }

    // 2. Check Player only if no AI is closer or if player is VERY close
    final playerDist = parent.position.distanceTo(game.player.position);
    // Player is only considered if they are significantly closer than any AI or if no AI in range
    if (playerDist < bestDist && (bestProxTarget == null || playerDist < 64)) {
      bestProxTarget = game.player;
    }

    if (bestProxTarget != null && bestProxTarget != target) {
      // Logic for switching targets
      bool canSwitch = false;
      _hasBeenSurprised = false; // Reset surprise for new target

      // Switch if we are just wandering/idle
      if (state == MonsterState.idle) canSwitch = true;
      
      // Switch if we are hunting a building (Buildings are boring compared to humans)
      if (target is DoorEntity || target is BedEntity) {
         // Only switch from building to player if player is very close
         if (bestProxTarget is PlayerEntity) {
            if (playerDist < 96) canSwitch = true;
         } else {
            canSwitch = true; // Always switch to AI
         }
      }

      // Switch if we are hunting another human but this one is much closer
      if (target is PlayerEntity || target is HunterAIEntity) {
         final currentDist = parent.position.distanceTo(target!.position);
         if (bestDist < currentDist * 0.5) canSwitch = true;
      }

      if (canSwitch) {
        debugPrint('[MONSTER] Proximity Aggro: Switching to ${bestProxTarget.runtimeType}');
        target = bestProxTarget;
        state = MonsterState.hunting;
        _calculatePathToTarget();
      }
    }
  }

  void _updateSkills(double dt) {
    _stunCooldown += dt;
    if (_stunCooldown >= stunCooldown) {
      // STRATEGIC AREA STUN: Disable buildings and repairs in a 3-tile radius
      const double areaStunRange = 96.0;

      final buildings = game.buildings
          .where((b) => b.center.distanceTo(parent.center) < areaStunRange)
          .toList();

      if (buildings.isNotEmpty) {
        // Trigger stun if ANY turret is shooting or if CURRENT TARGET is being repaired
        bool shouldStun = false;

        // 1. If currently attacking a door being repaired
        if (target != null && target!.isBeingRepaired && parent.center.distanceTo(target!.center) < areaStunRange) {
          shouldStun = true;
        }

        // 2. If any turret is in range (Proactive stun)
        if (!shouldStun) {
          for (final b in buildings) {
            if (b is TurretEntity && !b.isStunned) {
              shouldStun = true;
              break;
            }
          }
        }

        if (shouldStun) {
          _stunCooldown = 0;          debugPrint(
            '[MONSTER] SKILL: Area Stun triggered! Disabling ${buildings.length} buildings.',
          );

          // Visual feedback for area stun
          parent.flashColor(Colors.purpleAccent);
          parent.pulse(1.4);

          for (final b in buildings) {
            // Apply standardized stun to ALL buildings in range
            b.stun(stunDuration);
            
            if (b is TurretEntity) {
              debugPrint('[MONSTER]   -> Stunned Turret at ${b.position}');
            }
            if (b is DoorEntity) {
              debugPrint('[MONSTER]   -> Interrupted Repairs for Door');
            }
          }
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

  BaseEntity? _lastTarget;
  double _travelTimer = 0;
  double _stunCooldown = 0;

  void _handleHunting(double dt) {
    if (target == null || target!.isDestroyed) {
      debugPrint('[MONSTER] Target invalid or destroyed. Picking new target.');
      _pickNewTarget();
      return;
    }

    _travelTimer += dt;

    // Proximity check: Force the monster to be right next to the target
    double dist = parent.center.distanceTo(target!.center);
    
    // RANGE TWEAK: Beds are large (32x32) and the ghost is offset (bottomCenter).
    // We increase attack range for beds to 64 to prevent "jitter" stalemates.
    double attackDist = (target is DoorEntity) ? 48 : 64; 
    
    if (dist < attackDist) {
      // LINE OF SIGHT CHECK: Prevent killing through walls
      bool hasLoS = game.hasLineOfSight(parent.center, target!.center);

      if (!hasLoS) {
        // We are close but a wall is in the way. Stay in hunting mode to find the door.
      } else {
        // ONLY switch to attacking if the target is actually valid to attack (Occupied)
        bool canAttack = true;
        if (target is DoorEntity &&
            !_isRoomOccupied((target as DoorEntity).roomID)) {
          canAttack = false;
        } else if (target is BedEntity && !(target as BedEntity).isOccupied) {
          canAttack = false;
        }

        if (canAttack) {
          debugPrint(
            '[MONSTER] Reached target in ${_travelTimer.toStringAsFixed(2)}s. Switching to attacking.',
          );
          state = MonsterState.attacking;
          currentPath = [];
          _travelTimer = 0;
          _frustrationTimer = 0; // Reset frustration when we successfully start attacking
          return;
        } else {
          debugPrint(
            '[MONSTER] Reached target but room is empty. Finding new target.',
          );
          _lastTarget = target;
          _pickNewTarget();
          _travelTimer = 0;
          return;
        }
      }
    }

    // FRUSTRATION FIX: If we are hunting a building for more than 10s and not moving, give up.
    if (target is DoorEntity || target is BedEntity) {
      _frustrationTimer += dt;
      if (_frustrationTimer >= 10.0) {
        debugPrint('[MONSTER] Frustrated while hunting ${target.runtimeType}. Giving up.');
        _lastTarget = target;
        _frustrationTimer = 0;
        _pickNewTarget();
        return;
      }
    } else {
      _frustrationTimer = 0;
    }

    // Health check for retreat
    if (parent.hp / parent.maxHp < 0.2) {
      state = MonsterState.retreating;
      _calculatePathToSpawn();
      return;
    }

    // Path completion check
    if (currentPath.isEmpty || pathIndex >= currentPath.length) {
      if (dist < attackDist) {
        state = MonsterState.attacking;
        currentPath = [];
      } else {
        // If we still have distance but no path, try to repath
        if (!_calculatePathToTarget()) {
          debugPrint('[MONSTER] Path calculation failed during hunt. Picking new target.');
          _lastTarget = target;
          _pickNewTarget();
        }
      }
      return;
    }

    // Move along path
    final waypoint = currentPath[pathIndex];
    final moveDist = parent.position.distanceTo(waypoint);

    if (moveDist < 8) {
      debugPrint('[MONSTER] Waypoint reached: $pathIndex / ${currentPath.length}');
      pathIndex++;
    } else {
      final direction = (waypoint - parent.position).normalized();
      final nextPosition = parent.position + direction * parent.speed * dt;

      // Performance Optimized: Dynamic Building Collision Check
      // Using a slightly wider hitbox (40% width) for better collision reliability
      final nextRect = Rect.fromLTWH(
        nextPosition.x - parent.size.x * 0.20,
        nextPosition.y - parent.size.y * 0.05,
        parent.size.x * 0.4,
        parent.size.y * 0.1,
      );

      // DYNAMIC SMASHING: Smash through breakable buildings in path
      // This ensures the monster stops to destroy doors even if hunting the player.
      // WE ALWAYS check buildings, even if the monster is escaping a wall!
      final blockingEntity = game.getBlockingEntity(
        nextRect,
        ignoredEntities:
            (target is DoorEntity || target is BedEntity) ? [] : [target!],
      );

      if (blockingEntity != null && !blockingEntity.isDestroyed) {
        if (blockingEntity is DoorEntity && blockingEntity.isOpen) {
          // Keep moving!
        } else {
          debugPrint(
            '[MONSTER] Path blocked by ${blockingEntity.runtimeType}. Smashing it!',
          );
          target = blockingEntity;
          state = MonsterState.attacking;
          currentPath = [];
          return;
        }
      }

      // 2. Check for Static Walls
      // ESCAPE LOGIC: Only skip the wall check if ALREADY inside a wall.
      // Buildings (Doors) are NEVER skipped.
      final currentTileX =
          (parent.position.x / 32).floor().clamp(0, DreamHunterGame.gridW - 1);
      final currentTileY =
          (parent.position.y / 32).floor().clamp(0, DreamHunterGame.gridH - 1);
      bool isCurrentlyInWall = game.wallGrid[currentTileX][currentTileY];

      if (!isCurrentlyInWall &&
          game.isPositionBlocked(
            nextRect,
            ignoredEntities: [target!],
            targetPos: target!.position,
          )) {
        // SLIDING LOGIC: Try moving on only one axis if blocked
        final dx = nextPosition.x - parent.position.x;
        final dy = nextPosition.y - parent.position.y;

        bool blockedX = game.isPositionBlocked(
          nextRect.translate(dx, 0),
          ignoredEntities: [target!],
          targetPos: target!.position,
        );
        bool blockedY = game.isPositionBlocked(
          nextRect.translate(0, dy),
          ignoredEntities: [target!],
          targetPos: target!.position,
        );

        if (!blockedX || !blockedY) {
          // Slide enabled: Move on the clear axis
          if (!blockedX) parent.position.x = nextPosition.x;
          if (!blockedY) parent.position.y = nextPosition.y;
        } else {
          // Truly blocked: Throttle logging and check for attack range
          if (_logThrottleTimer > 1.0) {
            debugPrint(
              '[MONSTER] Path blocked by wall at $nextPosition. Target is at ${target!.position}.',
            );
            _logThrottleTimer = 0;
          }

          // Stop and attack if target is within reach
          if (target != null && parent.center.distanceTo(target!.center) < 48) {
            state = MonsterState.attacking;
            currentPath = [];
            return;
          }
          return;
        }
      } else {
        // Clear Path: Move forward
        parent.position = nextPosition;
      }

      // Snapping/Centering Logic: Pull toward the waypoint center to stay in halls
      // NEW: Added collision check to prevent snapping INTO walls at corners
      const double pullStrength = 10.0;
      Vector2 snapPos = parent.position.clone();
      if (direction.x.abs() > direction.y.abs()) {
        snapPos.y += (waypoint.y - parent.position.y) * pullStrength * dt;
      } else {
        snapPos.x += (waypoint.x - parent.position.x) * pullStrength * dt;
      }

      final snapRect = Rect.fromLTWH(
        snapPos.x - parent.size.x * 0.15,
        snapPos.y - parent.size.y * 0.05,
        parent.size.x * 0.3,
        parent.size.y * 0.1,
      );

      if (!game.isPositionBlocked(
        snapRect,
        ignoredEntities: [target!],
        targetPos: target!.position,
      )) {
        parent.position = snapPos;
      }

      parent.updateSprite(direction);
    }
  }

  void _handleAttacking(double dt, {bool shouldScan = false}) {
    if (target == null || target!.isDestroyed) {
      _pickNewTarget();
      return;
    }

    // MERCY LOGIC: Bias against destroying player's early-game doors
    if (shouldScan && target is DoorEntity) {
      final door = target as DoorEntity;
      final isPlayerRoom = door.roomID == MatchManager.instance.currentRoomID;
      
      // If Wood Door IV (Level 4) or below
      if (isPlayerRoom && door.totalUpgrades < 4) {
        // 15% chance every scan (0.25s) to just "give up" and retreat
        if (math.Random().nextDouble() < 0.15) {
          debugPrint('[MONSTER] MERCY: Retreated from player\'s early door (${door.totalUpgrades + 1})');
          state = MonsterState.retreating;
          _calculatePathToSpawn();
          
          game.world.add(
            FloatingFeedback(
              label: 'BORING...',
              color: Colors.amberAccent,
              position: parent.position + Vector2(0, -parent.size.y),
              icon: Icons.sentiment_neutral_rounded,
            ),
          );
          return;
        }
      }
    }

    // TARGET PROTECTION: Prevent accidental player kills
    // Monster must "focus" on the player for 1.5 seconds before it can deal damage.
    if (target is PlayerEntity) {
      _playerTargetingTimer += dt;
      if (_playerTargetingTimer < 1.5) {
        // Just staring/growling for the first 1.5 seconds
        if (_logThrottleTimer > 1.0) {
          debugPrint('[MONSTER] Locking onto Player... (${_playerTargetingTimer.toStringAsFixed(1)}s)');
        }
        return; 
      }
    } else {
      _playerTargetingTimer = 0;
    }

    // LINE OF SIGHT CHECK: Stop attacking if a wall gets in the way
    double dist = parent.center.distanceTo(target!.center);
    bool hasLoS = game.hasLineOfSight(parent.center, target!.center);
    if (!hasLoS) {
      debugPrint('[MONSTER] LoS lost during attack. Switching to hunting.');
      state = MonsterState.hunting;
      return;
    }

    // Health check for retreat (Ensure monster retreats if taking too much damage mid-fight)
    if (parent.hp / parent.maxHp < 0.2) {
      state = MonsterState.retreating;
      _calculatePathToSpawn();
      return;
    }

    // PROBABILISTIC SURPRISE: Triggered when HP increases significantly (10+ HP).
    if (!_hasBeenSurprised && target!.hp > _lastTargetHp + 10.0) {
      _hasBeenSurprised = true;
      
      // 70% chance to STAY and keep attacking (Persistence)
      // 30% chance to be "surprised" and retreat
      if (math.Random().nextDouble() < 0.3) {
        debugPrint('[MONSTER] Surprised by healing! Retreating.');
        _surpriseTimer = 3.0; // Retreat for 3 seconds
        state = MonsterState.retreating;
        _calculatePathToSpawn();
        _lastTargetHp = target!.hp;

        game.world.add(
          FloatingFeedback(
            label: '?',
            color: Colors.cyanAccent,
            position: parent.position + Vector2(0, -parent.size.y),
            icon: Icons.help_outline_rounded,
          ),
        );
        parent.flashColor(Colors.cyanAccent);
        return;
      } else {
        debugPrint('[MONSTER] Persistent! Ignoring the healing and staying.');
        // Visual cue that it's angry/persistent
        game.world.add(
          FloatingFeedback(
            label: 'GRRR!',
            color: Colors.redAccent,
            position: parent.position + Vector2(0, -parent.size.y),
            icon: Icons.bolt,
          ),
        );
        parent.flashColor(Colors.redAccent);
      }
    }
    _lastTargetHp = target!.hp;

    // Must stay close to keep attacking
    // MaxDist must be larger than attackDist to prevent jitter
    // Bed attackDist is 64, so we use 72 here for a small buffer.
    double maxDist = (target is DoorEntity) ? 60 : 72;

    if (_logThrottleTimer > 1.0) {
      debugPrint(
          '[MONSTER] RANGE CHECK: Dist to ${target.runtimeType} is ${dist.toStringAsFixed(1)}px (${(dist / 32).toStringAsFixed(1)} tiles). Max allowed: ${maxDist}px');
    }
    if (dist > maxDist) {
      debugPrint('[MONSTER] Target too far! Breaking attack (Dist: ${dist.toStringAsFixed(1)}px)');
      state = MonsterState.hunting;
      _frustrationTimer = 0; // Reset frustration if we lose contact
      return;
    }

    // NEW: Frustration Mechanic (Anti-Stall)
    // If we are hitting a Door or Bed for more than 15 seconds, we give up and find someone else.
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

    attackTimer += dt;
    if (attackTimer >= 1.0) {
      attackTimer = 0;
      _performAttack();
    }
  }

  void _handleRetreating(double dt) {
    // ...
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
      
      // DETERMINISTIC RE-ATTACK: Always resume hunt at 70% HP
      if (parent.hp >= parent.maxHp * 0.7 && parent.hp < parent.maxHp) {
        // Visual Cue for "Rage/Re-entry"
        game.world.add(
          FloatingFeedback(
            label: '!',
            color: Colors.redAccent,
            position: parent.position + Vector2(0, -parent.size.y),
            icon: Icons.priority_high_rounded,
          ),
        );
        parent.flashColor(Colors.redAccent);
        
        _pickNewTarget();
        return;
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
    _hasBeenSurprised = false; // Reset surprise state for the new target
    // STRATEGIC REFACTOR: Use the Target Registry instead of scanning the map.
    final bestTargetIDs = MatchManager.instance.getBestTargets();

    if (bestTargetIDs.isEmpty) {
      state = MonsterState.idle;
      target = null;
      debugPrint('[MONSTER] No targets in registry.');
      return;
    }

    // Find the first target from the registry that exists in the world
    for (final id in bestTargetIDs) {
      // Find door or bed in this room
      final buildings = game.getBuildingsInRoom(id);
      if (buildings.isNotEmpty) {
        // Prefer Door if not destroyed
        final door = buildings.whereType<DoorEntity>().firstOrNull;
        if (door != null && !door.isDestroyed && door != _lastTarget) {
          target = door;
          state = MonsterState.hunting;
          _travelTimer = 0; // Reset timer for new target
          if (_calculatePathToTarget()) {
            debugPrint('[MONSTER] Target picked: Door in room $id');
            return;
          }
        }

        final bed = buildings.whereType<BedEntity>().firstOrNull;
        if (bed != null && !bed.isDestroyed && bed != _lastTarget) {
          target = bed;
          state = MonsterState.hunting;
          _travelTimer = 0; // Reset timer for new target
          if (_calculatePathToTarget()) {
            debugPrint('[MONSTER] Target picked: Bed in room $id');
            return;
          }
        }
      }
    }

    // Fallback: If everything was _lastTarget or unreachable, try again without exclusions
    if (_lastTarget != null) {
      _lastTarget = null;
      _pickNewTarget();
      return;
    }

    state = MonsterState.idle;
    target = null;
    debugPrint(
      '[MONSTER] Failed to find physical entity or path for registry targets.',
    );
  }

  bool _calculatePathToTarget() {
    if (target == null) return false;
    final sw = Stopwatch()..start();
    final path = game.getShortestPath(parent.position, target!.position);
    sw.stop();

    if (path.isEmpty) return false;

    currentPath = path;
    pathIndex = 0;
    debugPrint(
      '[MONSTER] Path calculated to ${target!.position} in ${sw.elapsedMicroseconds}us. Length: ${currentPath.length}',
    );
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
      final sw = Stopwatch()..start();
      currentPath = game.getShortestPath(parent.position, nearestSpawn);
      sw.stop();
      pathIndex = 0;
      debugPrint('[MONSTER] Path to spawn calculated in ${sw.elapsedMicroseconds}us.');
    }
  }

  void _performAttack() {
    if (target == null || target!.isDestroyed) {
      _pickNewTarget();
      return;
    }

    // FINAL RANGE & LOS ENFORCEMENT: Double check distance and LoS at the moment of damage
    final dist = parent.center.distanceTo(target!.center);
    final maxDist = (target is DoorEntity) ? 64.0 : 68.0; // Slightly larger for grace
    
    // STRICT LoS CHECK: Prevent killing through walls or closed doors
    bool hasLoS = game.hasLineOfSight(parent.center, target!.center);

    if (dist > maxDist || !hasLoS) {
      debugPrint('[MONSTER] ATTACK FAILED: ${!hasLoS ? "LoS Blocked" : "Out of Range"} (Dist: ${dist.toStringAsFixed(1)}px)');
      state = MonsterState.hunting;
      _calculatePathToTarget(); // Try to find a way around
      return;
    }

    final double damage = parent.attackDamage;
    debugPrint(
      '[MONSTER] ATTACK! Damage: ${damage.toStringAsFixed(1)} to ${target.runtimeType} (HP: ${target!.hp.toStringAsFixed(1)}/${target!.maxHp.toStringAsFixed(1)}) (Dist: ${dist.toStringAsFixed(1)}px)',
    );

    // Visual pulse: More dramatic and visible
    parent.add(
      ScaleEffect.to(
        Vector2.all(1.4),
        EffectController(duration: 0.15, reverseDuration: 0.15),
      ),
    );

    final bool wasDestroyedBefore = target!.isDestroyed;

    target!.takeDamage(damage);

    // BLOODY ROOM: If we just killed a hunter, mark the entire room as bloody
    if (target is PlayerEntity || target is HunterAIEntity) {
      if (target!.hp <= 0) {
        final roomID = target!.roomID;
        if (roomID.isNotEmpty) {
          debugPrint('[MONSTER] Kill confirmed in $roomID. Marking room as bloody.');
          final fog = game.roomFog[roomID];
          if (fog != null) {
            fog.markDeath();
          }
        }
      }
    }

    // DOOR-TO-BED CHAIN TARGETING: If we just destroyed a door, target the bed in that room
    if (target is DoorEntity && !wasDestroyedBefore && target!.isDestroyed) {
      final roomID = (target as DoorEntity).roomID;
      final bed = game.roomBeds[roomID];
      if (bed != null && !bed.isDestroyed) {
        debugPrint('[MONSTER] Door destroyed! Chaining target to Bed in $roomID');
        target = bed;
        state = MonsterState.hunting;
        _calculatePathToTarget();
        return;
      }
    }

    // BED DESTRUCTION LOGIC
    if (target is BedEntity && !wasDestroyedBefore && target!.isDestroyed) {
      final bed = target as BedEntity;
      if (bed.owner != null && !bed.owner!.isDestroyed) {
        debugPrint('[MONSTER] Bed destroyed! Killing sleeper ${bed.owner.runtimeType}');
        bed.owner!.takeDamage(1000.0); // Instant kill
      }
      
      // Immediately try to find a way out of the room and find the NEXT target
      _escapeRoomAfterKill();
      return;
    }

    // DOOR-TO-BED CHAIN TARGETING: If we just destroyed a door, target the bed in that room
    if (target is DoorEntity && !wasDestroyedBefore && target!.isDestroyed) {
      final roomID = (target as DoorEntity).roomID;
      final bed = game.roomBeds[roomID];
      if (bed != null && !bed.isDestroyed) {
        debugPrint('[MONSTER] Door destroyed! Chaining target to Bed in $roomID');
        target = bed;
        state = MonsterState.hunting;
        _calculatePathToTarget();
        return;
      }
    }

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
    } else if (target!.hasCategory('player') ||
        target!.hasCategory('ai_hunter')) {
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
      final double bonusXP =
          (!wasDestroyedBefore && door.isDestroyed) ? 20.0 : 0.0;

      parent.gainExperience((xpGained + bonusXP).floor());
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

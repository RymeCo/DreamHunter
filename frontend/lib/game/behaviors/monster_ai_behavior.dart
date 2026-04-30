import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:dreamhunter/game/entities/monster_entity.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/entities/door_entity.dart';
import 'package:dreamhunter/game/entities/bed_entity.dart';
import 'package:dreamhunter/game/entities/turret_entity.dart';

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

  final double stunCooldown = 15.0;
  final double stunDuration = 3.0;
  final double stunRange = 64.0;

  @override
  void update(double dt) {
    super.update(dt);

    if (parent.isDestroyed) return;

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

  void _updateSkills(double dt) {
    stunTimer += dt;
    if (stunTimer >= stunCooldown) {
      final turrets = game.world.children
          .whereType<TurretEntity>()
          .where((t) => t.position.distanceTo(parent.position) < stunRange);

      if (turrets.isNotEmpty) {
        stunTimer = 0;
        for (final turret in turrets) {
          turret.stun(stunDuration);
        }
      }
    }
  }

  void _handleIdle(double dt) {
    decisionTimer += dt;
    if (decisionTimer >= 1.0) {
      decisionTimer = 0;
      _pickNewTarget();
    }
  }

  void _handleHunting(double dt) {
    if (target == null || target!.isDestroyed) {
      _pickNewTarget();
      return;
    }

    // Health check for retreat
    if (parent.hp / parent.maxHp < 0.2) {
      state = MonsterState.retreating;
      _calculatePathToSpawn();
      return;
    }

    if (currentPath.isEmpty || pathIndex >= currentPath.length) {
      if (parent.position.distanceTo(target!.position) < 40) {
        state = MonsterState.attacking;
      } else {
        _calculatePathToTarget();
      }
      return;
    }

    // Move along path
    final waypoint = currentPath[pathIndex];
    final dist = parent.position.distanceTo(waypoint);

    if (dist < 4) {
      pathIndex++;
    } else {
      final direction = (waypoint - parent.position).normalized();
      parent.position += direction * parent.speed * dt;

      // Flip sprite
      if (direction.x < -0.1) {
        parent.scale.x = -1;
      } else if (direction.x > 0.1) {
        parent.scale.x = 1;
      }
    }
  }

  void _handleAttacking(double dt) {
    if (target == null || target!.isDestroyed) {
      _pickNewTarget();
      return;
    }

    if (parent.position.distanceTo(target!.position) > 48) {
      state = MonsterState.hunting;
      return;
    }

    attackTimer += dt;
    if (attackTimer >= 1.0) {
      attackTimer = 0;
      _performAttack();
    }
  }

  void _handleRetreating(double dt) {
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
      if (healAggressionTimer >= 10.0) { // Every 10% health approximately
        healAggressionTimer = 0;
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
      }
    }
  }

  void _pickNewTarget() {
    final rand = math.Random().nextDouble();
    if (rand < 0.25) {
      target = game.player;
    } else {
      // Target most vulnerable door
      final doors = game.world.children.whereType<DoorEntity>().where((d) => !d.isDestroyed).toList();
      if (doors.isNotEmpty) {
        doors.sort((a, b) => (a.hp / a.maxHp).compareTo(b.hp / b.maxHp));
        target = doors.first;
      } else {
        // All doors gone? Target beds.
        final beds = game.world.children.whereType<BedEntity>().where((b) => !b.isDestroyed).toList();
        if (beds.isNotEmpty) {
          target = beds[math.Random().nextInt(beds.length)];
        }
      }
    }

    if (target != null) {
      state = MonsterState.hunting;
      _calculatePathToTarget();
    }
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

    // Visual pulse
    parent.add(
      ScaleEffect.to(
        Vector2.all(1.2),
        EffectController(duration: 0.1, reverseDuration: 0.1),
      ),
    );

    target!.takeDamage(parent.attackDamage);
    parent.gainExperience(target!.isDestroyed ? 10 : 1);
  }
}

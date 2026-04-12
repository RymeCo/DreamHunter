import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../haunted_dorm_game.dart';
import '../core/game_config.dart';
import '../objects/door.dart';
import '../objects/bed.dart';
import '../level/collision_block.dart';
import '../core/pathfinder.dart';

enum GhostState {
  idle,
  hunting,
  movingToDoor,
  attackingDoor,
  enteringRoom,
  movingToBed,
  attackingBed,
  retreating,
}

class Ghost extends SpriteComponent with HasGameReference<HauntedDormGame> {
  GhostState _state = GhostState.idle;
  Door? _targetDoor;
  Bed? _targetBed;

  List<Vector2>? _currentPath;
  int _pathIndex = 0;

  double _health = GameConfig.baseMonsterHealth;
  double _maxHealth = GameConfig.baseMonsterHealth;
  double _attackPower = GameConfig.baseMonsterAttack;

  double _levelTimer = 0;
  double _attackTimer = 0;
  final Random _random = Random();
  late final RectangleComponent _hpBar;

  List<CollisionBlock> collisionBlocks = [];

  Ghost({required super.position, required super.size});

  @override
  FutureOr<void> onLoad() async {
    priority = 6;
    sprite = await game.loadSprite('game/monsters/ghost_idle-32x48.png');
    anchor = Anchor.center;

    _hpBar = RectangleComponent(
      size: Vector2(width, 4),
      position: Vector2(0, -10),
      paint: Paint()..color = Colors.redAccent,
    );
    add(_hpBar);

    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);

    _levelTimer += dt;
    if (_levelTimer >= GameConfig.monsterUpgradeTime) {
      _levelTimer = 0;
      _levelUp();
    }

    _hpBar.width = width * (_health / _maxHealth);

    switch (_state) {
      case GhostState.idle:
        if (!game.isGracePeriod) _setState(GhostState.hunting);
        break;
      case GhostState.hunting:
        _findNewTarget();
        break;
      case GhostState.movingToDoor:
        _followPath(dt, nextState: GhostState.attackingDoor);
        break;
      case GhostState.attackingDoor:
        _attackDoor(dt);
        break;
      case GhostState.enteringRoom:
        _pathfindToBed();
        break;
      case GhostState.movingToBed:
        _followPath(dt, nextState: GhostState.attackingBed);
        break;
      case GhostState.attackingBed:
        _attackBed(dt);
        break;
      case GhostState.retreating:
        _retreat(dt);
        break;
    }
  }

  /// Internal state switcher that ensures visuals are reset
  void _setState(GhostState newState) {
    if (_state == newState) return;
    _state = newState;
    _resetVisuals(); // Prevents "Squish" bug by resetting scale
  }

  void _resetVisuals() {
    // Reset scale while preserving flip
    final double currentFlip = scale.x.sign;
    scale = Vector2(currentFlip * 1.0, 1.0);
    // Remove any leftover effects
    children.whereType<ScaleEffect>().forEach((e) => e.removeFromParent());
  }

  void takeDamage(double amount) {
    _health -= amount;
    add(
      ColorEffect(
        const Color(0x88FFFFFF),
        EffectController(duration: 0.1, reverseDuration: 0.1),
      ),
    );
    if (_health <= (_maxHealth * 0.2)) _setState(GhostState.retreating);
  }

  void _levelUp() {
    _maxHealth *= GameConfig.hpScaleFactor;
    _health = _maxHealth;
    _attackPower *= GameConfig.atkScaleFactor;
    add(
      ColorEffect(
        const Color(0xFFFF0000),
        EffectController(duration: 0.5, reverseDuration: 0.5),
      ),
    );
  }

  void _findNewTarget() {
    final occupiedDoors = game.level.allDoors
        .where((d) => d.associatedBed != null)
        .toList();
    if (occupiedDoors.isEmpty) return;

    bool targetPlayer = _random.nextDouble() < GameConfig.playerTargetBias;
    if (targetPlayer && game.player.currentBed != null) {
      _targetDoor = game.level.allDoors.firstWhere(
        (d) => d.roomID == game.player.currentBed!.roomID,
        orElse: () => occupiedDoors[_random.nextInt(occupiedDoors.length)],
      );
    } else {
      _targetDoor = occupiedDoors[_random.nextInt(occupiedDoors.length)];
    }

    if (_targetDoor != null) {
      _currentPath = Pathfinder.findPath(
        start: position,
        target: _targetDoor!.position + (_targetDoor!.size / 2),
        isWalkable: _isPosWalkable,
      );
      if (_currentPath != null && _currentPath!.isNotEmpty) {
        _pathIndex = 0;
        _setState(GhostState.movingToDoor);
      }
    }
  }

  bool _isPosWalkable(int x, int y) {
    final rect = Rect.fromLTWH(x * 32.0, y * 32.0, 32, 32);
    for (final block in collisionBlocks) {
      if (_targetDoor != null && block == _targetDoor!.collisionBlock) continue;
      if (!block.isPassable && block.toRect().overlaps(rect)) return false;
    }
    return true;
  }

  void _followPath(double dt, {GhostState? nextState}) {
    if (_currentPath == null || _pathIndex >= _currentPath!.length) {
      if (nextState != null) _setState(nextState);
      return;
    }

    final target = _currentPath![_pathIndex];
    final direction = target - position;
    if (direction.length < 5) {
      _pathIndex++;
      return;
    }
    position += direction.normalized() * 100 * dt;
    if (direction.x < 0 && scale.x > 0) scale.x = -1;
    if (direction.x > 0 && scale.x < 0) scale.x = 1;
  }

  void _attackDoor(double dt) {
    if (_targetDoor == null) {
      _setState(GhostState.hunting);
      return;
    }
    if (_targetDoor!.isOpen) {
      _targetBed = _targetDoor!.associatedBed;
      _setState(GhostState.enteringRoom);
      return;
    }

    _attackTimer += dt;
    if (_attackTimer >= 1.0) {
      _attackTimer = 0;
      _targetDoor!.takeDamage(_attackPower);
      // FIXED: Use relative scale to prevent squish bug
      add(
        ScaleEffect.by(
          Vector2.all(1.1),
          EffectController(duration: 0.1, reverseDuration: 0.1),
        ),
      );
    }
  }

  void _pathfindToBed() {
    if (_targetBed == null) {
      _setState(GhostState.hunting);
      return;
    }
    _currentPath = Pathfinder.findPath(
      start: position,
      target: _targetBed!.position + (_targetBed!.size / 2),
      isWalkable: (x, y) => true,
    );
    if (_currentPath != null) {
      _pathIndex = 0;
      _setState(GhostState.movingToBed);
    }
  }

  void _attackBed(double dt) {
    if (_targetBed == null) {
      _setState(GhostState.hunting);
      return;
    }
    _attackTimer += dt;
    if (_attackTimer >= 1.0) {
      _attackTimer = 0;
      _targetBed!.takeDamage(_attackPower);
      add(
        ScaleEffect.by(
          Vector2.all(1.1),
          EffectController(duration: 0.1, reverseDuration: 0.1),
        ),
      );
      if (_targetBed!.currentHealth <= 0) {
        _targetBed = null;
        _setState(GhostState.hunting);
      }
    }
  }

  void _retreat(double dt) {
    final spawnPos = Vector2(100, 100);
    final direction = spawnPos - position;
    if (direction.length < 10) {
      _health = _maxHealth;
      _setState(GhostState.hunting);
      return;
    }
    position += direction.normalized() * 150 * dt;
  }
}

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/entities/projectile_entity.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/widgets/game/upgrade_dialog.dart';

class TurretEntity extends BaseEntity with TapCallbacks {
  @override
  final String roomID;
  int level = 1;
  double fireRate = 1.0; // Seconds between shots
  double range = 150.0;
  double damage = 10.0;

  double _fireTimer = 0;
  double _scanTimer = 0;
  BaseEntity? _currentTarget;

  late Sprite _baseSprite;
  late Sprite _headSprite;
  late Sprite _projectileSprite;

  late SpriteComponent _baseComponent;
  late TurretHeadComponent head;

  TurretEntity({required super.position, required this.roomID})
    : super(size: Vector2.all(32), anchor: Anchor.center) {
    addCategory('building');
    addCategory('turret');
    maxHp = 1.0;
    hp = maxHp;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    game.registerTurret(this);
    await _updateSprites();

    // Add Base (Stationary)
    _baseComponent = SpriteComponent(
      sprite: _baseSprite,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_baseComponent);

    // Add Rotating Head
    head = TurretHeadComponent(sprite: _headSprite);
    add(head);

    _applyStats();
  }

  void _applyStats() {
    // NEW SCALE PROTOCOL:
    // Range: Minimum 4 tiles (128px) + 0.5 tiles (16px) per level increase.
    // Lv 1: 128px (4 tiles)
    // Lv 9: 128 + (8 * 16) = 256px (8 tiles)
    range = 128.0 + (level - 1) * 16.0;

    // SWEET SPOT DAMAGE (20% NERF APPLIED):
    // Starts higher but scales slightly less aggressively than before.
    // Base (12 + 8 per level) * 0.8. Lv 1 = 9.6, Lv 9 = 60.8
    damage = (12.0 + (level - 1) * 8.0) * 0.8;

    // Fire rate increases slightly (gets faster)
    fireRate = (1.0 - (level - 1) * 0.05).clamp(0.4, 1.0);
  }

  Future<void> _updateSprites() async {
    final spriteSheet = await game.images.load(
      'game/defenses/turret_sheet-32x32.png',
    );

    // level is 1-indexed, rows are 0-indexed. Max 9 rows.
    final int row = (level - 1).clamp(0, 8);

    _baseSprite = Sprite(
      spriteSheet,
      srcPosition: Vector2(0, row * 32),
      srcSize: Vector2.all(32),
    );

    _headSprite = Sprite(
      spriteSheet,
      srcPosition: Vector2(32, row * 32),
      srcSize: Vector2.all(32),
    );

    _projectileSprite = Sprite(
      spriteSheet,
      srcPosition: Vector2(64, row * 32),
      srcSize: Vector2.all(32),
    );

    if (isLoaded) {
      _baseComponent.sprite = _baseSprite;
      head.sprite = _headSprite;
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (level >= 9) {
      UpgradeDialog.show(
        game.buildContext!,
        title: "Defense Turret",
        currentLevel: level,
        requirements: [],
        coinCost: 0,
        upgradeBenefit: "MAXED OUT",
        isMaxLevel: true,
        onUpgrade: () {},
      );
      return;
    }

    final int cost = level * 150;
    final double nextDamage = (12.0 + level * 8.0) * 0.8;
    final double nextRange = 128.0 + level * 16.0;

    UpgradeDialog.show(
      game.buildContext!,
      title: "Defense Turret",
      currentLevel: level,
      requirements: [], // No hard requirements for turrets yet
      coinCost: cost,
      upgradeBenefit:
          "Lv. $level ➔ Lv. ${level + 1}\nDmg: ${damage.toInt()}➔${nextDamage.toInt()}, Range: ${range.toInt()}➔${nextRange.toInt()}\nMax 2 Active Per Room",
      onUpgrade: () async {
        tryUpgrade(game.player);
      },
    );
  }

  /// Attempts to upgrade the turret using the resources of the provided entity.
  /// Returns true if the upgrade was successful.
  Future<bool> tryUpgrade(BaseEntity entity) async {
    if (level >= 9) return false;

    final int cost = level * 150;

    // Resource Check & Deduction
    bool success = false;
    if (entity.hasCategory('player')) {
      success = MatchManager.instance.spendMatchCoins(cost);
    } else {
      if (entity.matchCoins >= cost) {
        entity.matchCoins -= cost;
        success = true;
      }
    }

    if (success) {
      level++;
      _applyStats();
      hp = maxHp; // Full heal on upgrade
      await _updateSprites();
      HapticManager.instance.medium();
      AudioManager.instance.playReward(); // Use reward sound for upgrade
      return true;
    }

    return false;
  }

  @override
  void onRemove() {
    game.unregisterTurret(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isStunned) {
      head.paint.color = Colors.blueGrey.withValues(alpha: 0.7);
      _currentTarget = null;
      return;
    } else {
      head.paint.color = Colors.white;
    }

    _fireTimer += dt;
    _scanTimer += dt;

    // Throttle scanning to once every 200ms
    if (_scanTimer >= 0.2) {
      _scanTimer = 0;

      // EXCLUSIVE TARGETING PROTOCOL: 
      // Only TWO turrets per room can be "active" at a time to reduce visual clutter 
      // and prevent multiple turrets from wasting ammo on the same target.
      final activeTurretsCount = game.turrets.whereType<TurretEntity>().where((t) => 
        t != this && 
        t.roomID == roomID && 
        t._currentTarget != null && 
        !t.isStunned
      ).length;

      if (activeTurretsCount >= 2) {
        _currentTarget = null;
      } else {
        _currentTarget = _findNearestMonster();
      }
    }

    if (_currentTarget != null) {
      // LINE OF SIGHT CHECK: Don't shoot through walls
      // We pass roomID so the turret can "see through" its own door to defend it.
      if (!game.hasLineOfSight(center, _currentTarget!.center, ignoredRoomID: roomID)) {
        _currentTarget = null;
        return;
      }

      // Rotate head to target center
      final angle = atan2(
        _currentTarget!.center.y - center.y,
        _currentTarget!.center.x - center.x,
      );
      head.angle = angle;

      // Fire if ready
      if (_fireTimer >= fireRate) {
        _fireTimer = 0;
        _fire();
      }
    }
  }

  BaseEntity? _findNearestMonster() {
    BaseEntity? nearest;
    double minDistance = range;

    for (final monster in game.monsters) {
      if (monster.isDestroyed) continue;
      final dist = center.distanceTo(monster.center);
      if (dist < minDistance) {
        minDistance = dist;
        nearest = monster;
      }
    }
    return nearest;
  }

  void _fire() {
    if (_currentTarget == null) return;
    
    // Play sound and rumble
    AudioManager.instance.playClick();
    
    // Determine ownership
    final isPlayerOwned = roomID == MatchManager.instance.currentRoomID;
    
    // VELOCITY UPGRADE: 1000px/s makes it virtually a 100% hit (tracer speed)
    final velocity = Vector2(cos(head.angle), sin(head.angle)) * 1000;

    game.world.add(
      ProjectileEntity(
        sprite: _projectileSprite,
        position: center.clone(),
        velocity: velocity,
        damage: damage,
        isPlayerOwned: isPlayerOwned,
      ),
    );
  }
}

class TurretHeadComponent extends SpriteComponent {
  TurretHeadComponent({required super.sprite})
    : super(
        size: Vector2.all(32),
        anchor: Anchor.center,
        position: Vector2(16, 16), // Center in parent
      );
}


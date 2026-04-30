import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
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
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
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
    // Scaling:
    // Lv 1: 10 dmg, 150 range
    // Lv 9: 90 dmg, 310 range
    damage = 10.0 + (level - 1) * 10.0;
    range = 150.0 + (level - 1) * 20.0;
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
    final double nextDamage = 10.0 + level * 10.0;
    final double nextRange = 150.0 + level * 20.0;

    UpgradeDialog.show(
      game.buildContext!,
      title: "Defense Turret",
      currentLevel: level,
      requirements: [], // No hard requirements for turrets yet
      coinCost: cost,
      upgradeBenefit:
          "Lv. $level ➔ Lv. ${level + 1}\nDmg: ${damage.toInt()}➔${nextDamage.toInt()}, Range: ${range.toInt()}➔${nextRange.toInt()}",
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
      await _updateSprites();
      HapticManager.instance.medium();
      AudioManager.instance.playReward(); // Use reward sound for upgrade
      return true;
    }

    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _fireTimer += dt;
    _scanTimer += dt;

    // Throttle scanning to once every 200ms
    if (_scanTimer >= 0.2) {
      _scanTimer = 0;
      _currentTarget = _findNearestMonster();
    }

    if (_currentTarget != null) {
      // Rotate head to target
      final angle = atan2(
        _currentTarget!.position.y - position.y,
        _currentTarget!.position.x - position.x,
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
      final dist = position.distanceTo(monster.position);
      if (dist < minDistance) {
        minDistance = dist;
        nearest = monster;
      }
    }
    return nearest;
  }

  void _fire() {
    AudioManager.instance.playClick();

    final velocity = Vector2(cos(head.angle), sin(head.angle)) * 400;

    game.world.add(
      ProjectileEntity(
        sprite: _projectileSprite,
        position: position.clone(),
        velocity: velocity,
        damage: damage,
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

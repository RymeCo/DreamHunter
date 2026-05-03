import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/components/wrench_component.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/widgets/game/upgrade_dialog.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/game/game_config.dart';
import 'package:dreamhunter/game/components/floating_feedback.dart';

/// A door building that can be opened or closed.
/// Every 5 upgrades increases the Tier (Wood -> Iron -> Gold).
/// The Level within a Tier is represented by Suffixes (I, II, III, IV, V).
class DoorEntity extends BaseEntity with TapCallbacks {
  @override
  final String roomID;
  bool isOpen = true;

  // Level and Health Properties
  int totalUpgrades = 0; // Current Level (0 to 14)

  DoorUpgrade get currentUpgrade => GameConfig.doorUpgrades[totalUpgrades];

  String get romanNumeral => currentUpgrade.suffix;

  String get levelName => currentUpgrade.name;

  double shieldHp = 0; // Current shield
  double maxShieldHp = 0; // Max shield provided by fridge

  @override
  int get entityLevel => totalUpgrades;

  late final SpriteComponent _spriteComponent;
  late Sprite _openSprite;
  late Sprite _closedSprite;

  late final TextComponent _levelText;

  // Ice Overlay (Subtle frost effect)
  late final RectangleComponent _iceOverlay;

  // Health Bar Components
  late final _RoundedBarComponent _hbBackground;
  late final _RoundedBarComponent _hbFill;
  late final _RoundedBarComponent _hbShield; // Added shield bar

  double _regenTimer = 0;
  double _passiveHealTimer = 0;

  DoorEntity({required super.position, required this.roomID})
    : super(size: Vector2.all(32), anchor: Anchor.topLeft) {
    addCategory('door');
    maxHp = currentUpgrade.hp;
    hp = maxHp;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1. Load initial sprites based on material
    await _updateSprites();

    // Register in Target Registry
    MatchManager.instance.updateTargetValue(
      id: roomID,
      position: position,
      entityLevel: totalUpgrades,
      hpPercent: 1.0,
    );

    _spriteComponent = SpriteComponent(
      sprite: isOpen ? _openSprite : _closedSprite,
      size: size,
    );
    add(_spriteComponent);

    // 2. Initialize Ice Overlay (Subtle)
    _iceOverlay = RectangleComponent(
      size: size,
      paint: Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
      children: [
        RectangleComponent(
          size: size,
          paint: Paint()
            ..color = Colors.cyanAccent.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        ),
      ],
    );
    // Hide by default
    _iceOverlay.scale = Vector2.zero();
    add(_iceOverlay);

    // 3. Initialize Health Bar (Moved to foot level: y=26)
    _hbBackground = _RoundedBarComponent(
      position: Vector2(4, 26),
      size: Vector2(24, 5),
      radius: 2.5,
      paint: Paint()..color = Colors.black.withValues(alpha: 0.7),
    );

    _hbFill = _RoundedBarComponent(
      position: Vector2(0, 0),
      size: Vector2(24, 5),
      radius: 2.5,
      paint: Paint()..color = Colors.greenAccent,
    );

    _hbShield = _RoundedBarComponent(
      position: Vector2(0, 0),
      size: Vector2(0, 5),
      radius: 2.5,
      paint: Paint()..color = Colors.cyanAccent,
    );

    _hbBackground.add(_hbFill);
    _hbBackground.add(_hbShield);
    add(_hbBackground);

    // 4. Initialize Level Text Indicator
    _levelText = TextComponent(
      text: romanNumeral,
      textRenderer: TextPaint(
        style: GoogleFonts.quicksand(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          shadows: [
            const Shadow(
              blurRadius: 2.0,
              color: Colors.black,
              offset: Offset(1.0, 1.0),
            ),
          ],
        ),
      ),
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2 - 4),
    );
    add(_levelText);

    _updateLevelText();
    _updateHealthBar();

    if (!isOpen) {
      addCategory('building');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDestroyed) return;

    // Passive Healing: 0.5% HP every 2 seconds if closed, not at max HP and NOT stunned
    if (!isOpen && hp < maxHp && !isStunned) {
      _passiveHealTimer += dt;
      if (_passiveHealTimer >= 2.0) {
        _passiveHealTimer = 0;
        final double passiveHeal = math.max(1.0, maxHp * 0.005); // Min 1hp heal
        hp = (hp + passiveHeal).clamp(0, maxHp);
        
        _updateHealthBar();

        // Show subtle feedback for passive healing
        game.world.add(
          FloatingFeedback(
            label: '+${passiveHeal.toInt()}hp',
            color: Colors.greenAccent.withValues(alpha: 0.7),
            position: position + Vector2(size.x / 2, 0),
            icon: Icons.add_circle_outline_rounded,
            baseScale: 0.8, // Smaller than manual repair
          ),
        );
      }
    } else {
      _passiveHealTimer = 0;
    }

    if (isOpen) {
      isBeingRepaired = false;
      return;
    }

    // Manual Repair Visualization
    if (isBeingRepaired) {
      // Check if wrench already exists (optimized)
      bool hasWrench = false;
      for (final child in children) {
        if (child is WrenchComponent) {
          hasWrench = true;
          break;
        }
      }
      if (!hasWrench) {
        add(WrenchComponent()..position = Vector2(size.x - 4, size.y / 2));
      }
    }

    // Manual Repair Logic: 2% every 1s (ONLY when isBeingRepaired is true and NOT stunned)
    if (isBeingRepaired && !isStunned && (hp < maxHp || shieldHp < maxShieldHp)) {
      _regenTimer += dt;
      if (_regenTimer >= 1.0) {
        _regenTimer = 0;

        final double hpHeal = math.max(1.0, maxHp * 0.02); // Min 1hp heal
        final double shieldHeal = math.max(1.0, maxShieldHp * 0.02);

        // Heal HP
        if (hp < maxHp) {
          hp = (hp + hpHeal).clamp(0, maxHp);
          
          // Bigger feedback for active repair
          game.world.add(
            FloatingFeedback(
              label: '+${hpHeal.toInt()}hp',
              color: Colors.greenAccent,
              position: position + Vector2(size.x / 2, -8),
              icon: Icons.handyman_rounded,
              duration: 1.0, // Faster
              upSpeed: 60.0, // Double speed
              baseScale: 1.4, // Bigger
            ),
          );
        }

        // Heal Shield
        if (shieldHp < maxShieldHp) {
          shieldHp = (shieldHp + shieldHeal).clamp(0, maxShieldHp);
        }

        _updateHealthBar();
      }
    } else {
      _regenTimer = 0;
    }
  }

  void _updateLevelText() {
    if (isDestroyed) return;
    _levelText.text = isOpen ? '' : romanNumeral;
  }

  Future<void> _updateSprites() async {
    final material = currentUpgrade.material.toLowerCase();
    String assetName = material;
    if (material == 'iron') assetName = 'steel'; // Map 'iron' to 'steel' assets

    _openSprite = await Sprite.load(
      'game/defenses/door_${assetName}_open-32x32.png',
    );
    _closedSprite = await Sprite.load(
      'game/defenses/door_$assetName-32x32.png',
    );

    if (isLoaded) {
      _spriteComponent.sprite = isOpen ? _openSprite : _closedSprite;
    }
  }

  @override
  void takeDamage(double amount, {bool isPlayerOwned = false}) {
   if (isDestroyed) return;
    // Apply Shield Logic
    if (shieldHp > 0) {
      if (shieldHp >= amount) {
        shieldHp -= amount;
        amount = 0;
      } else {
        amount -= shieldHp;
        shieldHp = 0;
      }
    }

    if (amount > 0) {
      hp = (hp - amount).clamp(0, maxHp);
    }

    // Update Target Registry
    MatchManager.instance.updateTargetValue(
      id: roomID,
      position: position,
      hpPercent: hp / maxHp,
    );

    _updateHealthBar();
    if (hp <= 0) destroy();
  }

  void _updateHealthBar() {
    if (isDestroyed) return;
    final bool isDamaged = hp < maxHp || shieldHp > 0;

    if (isDamaged && !isOpen) {
      _hbBackground.renderBar = true;
      _hbFill.renderBar = true;
      _hbShield.renderBar = shieldHp > 0;

      // Fill Green bar based on HP
      _hbFill.size.x = (hp / maxHp) * 24.0;

      // Fill Cyan bar based on Shield
      if (shieldHp > 0) {
        _hbShield.size.x = (shieldHp / maxHp).clamp(0, 1) * 24.0;
        _iceOverlay.scale = Vector2.all(1.0);

        // Subtle color filter instead of solid tint
        _spriteComponent.paint.colorFilter = const ColorFilter.mode(
          Colors.cyanAccent,
          BlendMode.plus,
        );
        _spriteComponent.paint.color = Colors.white.withValues(alpha: 0.9);
      } else {
        _iceOverlay.scale = Vector2.zero();
        _spriteComponent.paint.colorFilter = null;
        _spriteComponent.paint.color = Colors.white;
      }

      final hpPercent = hp / maxHp;
      if (hpPercent < 0.25) {
        _hbFill.paint.color = Colors.redAccent;
      } else if (hpPercent < 0.5) {
        _hbFill.paint.color = Colors.orangeAccent;
      } else {
        _hbFill.paint.color = Colors.greenAccent;
      }
    } else {
      _hbBackground.renderBar = false;
      _hbFill.renderBar = false;
      _hbShield.renderBar = false;
      _iceOverlay.scale = Vector2.zero();
      _spriteComponent.paint.colorFilter = null;
      _spriteComponent.paint.color = Colors.white;
    }
  }

  /// Sets the shield HP for this door.
  void setShield(double current, double max) {
    shieldHp = current;
    maxShieldHp = max;
    _updateHealthBar();
  }

  @override
  void destroy() {
    if (isDestroyed) return;
    _spriteComponent.removeFromParent();
    _hbBackground.removeFromParent();
    categories.remove('building');
    categories.remove('door'); // Fully clear categories to avoid being targeted
    HapticManager.instance.heavy();
    super.destroy();
  }

  void close() {
    if (!isOpen || isDestroyed) return;
    isOpen = false;
    _spriteComponent.sprite = _closedSprite;
    addCategory('building');
    _updateLevelText();
    _updateHealthBar();
  }

  void open() {
    if (isOpen || isDestroyed) return;
    isOpen = true;
    _spriteComponent.sprite = _openSprite;
    categories.remove('building');
    _updateLevelText();
    _updateHealthBar();
  }

  /// Attempts to upgrade the door using the resources of the provided entity.
  /// Returns true if the upgrade was successful.
  bool tryUpgrade(BaseEntity entity) {
    if (totalUpgrades >= GameConfig.doorUpgrades.length - 1) return false;

    final nextUpgrade = GameConfig.doorUpgrades[totalUpgrades + 1];

    // 2. Resource Check & Deduction
    bool success = false;
    if (entity.hasCategory('player')) {
      // Player uses MatchManager
      success = MatchManager.instance.spendResources(
        coins: nextUpgrade.cost.coins,
        energy: nextUpgrade.cost.energy,
      );
    } else {
      // AI uses their own matchCoins/matchEnergy
      if (entity.matchCoins >= nextUpgrade.cost.coins &&
          entity.matchEnergy >= nextUpgrade.cost.energy) {
        entity.matchCoins -= nextUpgrade.cost.coins;
        entity.matchEnergy -= nextUpgrade.cost.energy;
        success = true;
      }
    }

    if (success) {
      totalUpgrades++;
      maxHp = currentUpgrade.hp;
      hp = maxHp;

      // Update Target Registry
      MatchManager.instance.updateTargetValue(
        id: roomID,
        position: position,
        entityLevel: totalUpgrades,
        hpPercent: hp / maxHp,
      );

      _updateSprites(); // Sprite load is async but safe to fire and forget here
      _updateLevelText();
      _updateHealthBar();

      HapticManager.instance.medium();
      return true;
    }

    return false;
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (isDestroyed) return;
    final manager = MatchManager.instance;
    if (manager.currentRoomID != roomID) return;

    if (totalUpgrades >= GameConfig.doorUpgrades.length - 1) {
      UpgradeDialog.show(
        game.buildContext!,
        title: "Door",
        currentLevel: totalUpgrades + 1,
        levelDisplay: _buildLevelWidget(),
        requirements: [],
        coinCost: 0,
        upgradeBenefit: "MAXED OUT",
        isMaxLevel: true,
        onUpgrade: () {},
      );
      return;
    }

    final nextUpgrade = GameConfig.doorUpgrades[totalUpgrades + 1];

    UpgradeDialog.show(
      game.buildContext!,
      title: "Door",
      currentLevel: totalUpgrades + 1,
      levelDisplay: _buildLevelWidget(),
      requirements: [],
      coinCost: nextUpgrade.cost.coins,
      energyCost: nextUpgrade.cost.energy,
      upgradeBenefit:
          "Lv. ${totalUpgrades + 1} ➔ Lv. ${totalUpgrades + 2}\n${maxHp.toInt()} ➔ ${nextUpgrade.hp.toInt()} HP",
      onUpgrade: () {
        tryUpgrade(
          MatchManager.instance.isHunterSleeping ? game.player : game.player,
        );
        // Note: simplified target selection for player, assuming game.player is always relevant
      },
    );
  }

  Widget _buildLevelWidget() {
    return Text(
      currentUpgrade.name.toUpperCase(),
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _RoundedBarComponent extends RectangleComponent {
  final double radius;
  bool renderBar = true;
  _RoundedBarComponent({
    required this.radius,
    super.position,
    super.size,
    super.paint,
  });
  @override
  void render(Canvas canvas) {
    if (!renderBar) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), Radius.circular(radius)),
      paint,
    );
  }

  @override
  void renderTree(Canvas canvas) {
    if (!renderBar) return;
    super.renderTree(canvas);
  }
}

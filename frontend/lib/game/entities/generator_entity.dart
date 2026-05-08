import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/entities/turret_entity.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/widgets/game/upgrade_dialog.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/game/components/floating_feedback.dart';
import 'package:dreamhunter/game/game_config.dart';

/// A building that generates Match Energy passively over time.
class GeneratorEntity extends BaseEntity with TapCallbacks {
  int level = 1;
  @override
  final String roomID;
  int _lastEnergyTick = 0;

  late final SpriteComponent _spriteComponent;
  late Sprite _spriteLv1;
  late Sprite _spriteLv2;
  late Sprite _spriteLv3;

  late final TextComponent _levelText;

  String get romanNumeral {
    const roman = ['I', 'II', 'III', 'IV', 'V', 'VI'];
    if (level <= roman.length) return roman[level - 1];
    return level.toString();
  }

  /// Gets the current level of this entity (for AI targeting decisions).
  @override
  int get entityLevel => level;

  @override
  int get sellValueCoins {
    int total = 0;
    for (int i = 0; i < level; i++) {
      total += GameConfig.generatorUpgrades[i].cost.coins;
    }
    return total;
  }

  @override
  int get sellValueEnergy {
    int total = 0;
    for (int i = 0; i < level; i++) {
      total += GameConfig.generatorUpgrades[i].cost.energy;
    }
    return total;
  }

  GeneratorEntity({
    required super.position,
    required this.roomID,
    this.level = 1,
  }) : super(size: Vector2.all(32), anchor: Anchor.topLeft) {
    addCategory('building');
    addCategory('generator');
    maxHp = 1.0;
    hp = maxHp;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _spriteLv1 = await game.loadSprite('game/economy/generator_lv1-32x32.png');
    _spriteLv2 = await game.loadSprite('game/economy/generator_lv2-32x32.png');
    _spriteLv3 = await game.loadSprite('game/economy/generator_lv3-32x32.png');

    _spriteComponent = SpriteComponent(sprite: _spriteLv1, size: size);
    add(_spriteComponent);

    // Initialize Level Text Indicator
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

    _updateSprite();

    // The energy generation logic has been migrated to BaseEntity.energyIncomePerTick
    // to correctly attribute energy to the hunter in the same room (Player or AI).
  }

  void _updateSprite() {
    if (level == 1) {
      _spriteComponent.sprite = _spriteLv1;
    } else if (level == 2) {
      _spriteComponent.sprite = _spriteLv2;
    } else {
      _spriteComponent.sprite = _spriteLv3;
    }
    _levelText.text = romanNumeral;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Visual feedback for energy generation
    final currentTicks = MatchManager.instance.energyTickCount;
    if (currentTicks > _lastEnergyTick) {
      _lastEnergyTick = currentTicks;
      _spawnEnergyParticle();
    }
  }

  void _spawnEnergyParticle() {
    final income = GameConfig.generatorUpgrades[level - 1].income;
    game.world.add(
      FloatingFeedback(
        label: '+$income',
        icon: Icons.bolt_rounded,
        color: Colors.cyanAccent,
        position: position + (size / 2),
      ),
    );
  }

  @override
  void onTapUp(TapUpEvent event) {
    // Max Level Check
    if (level >= GameConfig.generatorUpgrades.length) {
      UpgradeDialog.show(
        game.buildContext!,
        title: "Generator",
        currentLevel: level,
        requirements: [],
        coinCost: 0,
        upgradeBenefit: "MAXED OUT",
        isMaxLevel: true,
        onUpgrade: () {},
        onSell: () => sell(owner: game.player),
        sellRefundCoins: (sellValueCoins * 0.2).floor(),
        sellRefundEnergy: (sellValueEnergy * 0.2).floor(),
      );
      return;
    }

    final currentUpgrade = GameConfig.generatorUpgrades[level - 1];
    final nextUpgrade = GameConfig.generatorUpgrades[level];
    final List<UpgradeRequirement> reqs = [];

    if (nextUpgrade.requirementLabel != null) {
      final turrets = game.world.children.whereType<TurretEntity>().where(
        (t) => t.roomID == roomID,
      );
      int maxTurretLv = 0;
      if (turrets.isNotEmpty) {
        maxTurretLv = turrets.map((t) => t.level).reduce(math.max);
      }

      final bool isMet = nextUpgrade.checkRequirement!(maxTurretLv);
      reqs.add(
        UpgradeRequirement(label: nextUpgrade.requirementLabel!, isMet: isMet),
      );
    }

    final diff = nextUpgrade.income - currentUpgrade.income;

    UpgradeDialog.show(
      game.buildContext!,
      title: "Generator",
      currentLevel: level,
      requirements: reqs,
      coinCost: nextUpgrade.cost.coins,
      energyCost: nextUpgrade.cost.energy,
      upgradeBenefit:
          "Lv. $level ➔ Lv. ${level + 1}\n${currentUpgrade.income} ➔ ${nextUpgrade.income} (+$diff) Energy/Sec",
      onUpgrade: () {
        tryUpgrade(game.player);
      },
      onSell: () => sell(owner: game.player),
      sellRefundCoins: (sellValueCoins * 0.2).floor(),
      sellRefundEnergy: (sellValueEnergy * 0.2).floor(),
    );
  }

  /// Attempts to upgrade the generator using the resources of the provided entity.
  /// Returns true if the upgrade was successful.
  bool tryUpgrade(BaseEntity entity) {
    if (level >= GameConfig.generatorUpgrades.length) return false;

    final nextUpgrade = GameConfig.generatorUpgrades[level];

    // 1. Check Requirements (Turret level)
    if (nextUpgrade.requirementLabel != null) {
      final turrets = game.world.children.whereType<TurretEntity>().where(
        (t) => t.roomID == roomID,
      );
      int maxTurretLv = 0;
      if (turrets.isNotEmpty) {
        maxTurretLv = turrets.map((t) => t.level).reduce(math.max);
      }
      final bool isMet = nextUpgrade.checkRequirement!(maxTurretLv);
      if (!isMet) {
        return false;
      }
    }

    // 2. Resource Check & Deduction
    bool success = false;
    if (entity.hasCategory('player')) {
      success = MatchManager.instance.spendResources(
        coins: nextUpgrade.cost.coins,
        energy: nextUpgrade.cost.energy,
      );
    } else {
      if (entity.matchCoins >= nextUpgrade.cost.coins &&
          entity.matchEnergy >= nextUpgrade.cost.energy) {
        entity.matchCoins -= nextUpgrade.cost.coins;
        entity.matchEnergy -= nextUpgrade.cost.energy;
        success = true;
      }
    }

    if (success) {
      developer.log(
        'Upgrade: Generator in room $roomID upgraded to level $level (Owner: ${entity.hunterIndex ?? 'Unknown'})',
      );
      level++;
      hp = maxHp; // Heal to max HP on upgrade

      _updateSprite();
      HapticManager.instance.medium();
      AudioManager.instance.playClick();
      return true;
    }

    return false;
  }
}

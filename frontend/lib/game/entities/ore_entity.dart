import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/widgets/game/upgrade_dialog.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/game/game_config.dart';

/// A building that generates Match Coins passively over time.
/// Higher levels use more exotic ores and provide a global coin multiplier at Lv. 5.
class OreEntity extends BaseEntity with TapCallbacks {
  int level = 1;
  @override
  final String roomID;

  late final SpriteComponent _spriteComponent;
  final List<Sprite> _levelSprites = [];

  OreEntity({required super.position, required this.roomID, this.level = 1})
    : super(size: Vector2.all(32), anchor: Anchor.topLeft) {
    addCategory('building');
    addCategory('ore');
    maxHp = 1.0;
    hp = maxHp;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load all 5 ore sprites
    for (int i = 1; i <= 5; i++) {
      final sprite = await game.loadSprite('game/economy/lv${i}Ore-64x64.png');
      _levelSprites.add(sprite);
    }

    _spriteComponent = SpriteComponent(
      sprite: _levelSprites[level - 1], // Initialize with current level sprite
      size: size, // Scale 64x64 asset down to 32x32 slot
    );
    add(_spriteComponent);

    _updateVisuals();
  }

  void _updateVisuals() {
    if (level <= _levelSprites.length) {
      _spriteComponent.sprite = _levelSprites[level - 1];
    }
  }

  @override
  int get incomePerTick {
    if (level > 0 && level <= GameConfig.oreUpgrades.length) {
      return GameConfig.oreUpgrades[level - 1].income;
    }
    return 0;
  }

  @override
  void onTapUp(TapUpEvent event) {
    final manager = MatchManager.instance;
    if (manager.currentRoomID != roomID) return;

    if (level >= GameConfig.oreUpgrades.length) {
      UpgradeDialog.show(
        game.buildContext!,
        title: "Ore Mine",
        currentLevel: level,
        requirements: [],
        coinCost: 0,
        upgradeBenefit: "MAXED OUT",
        isMaxLevel: true,
        onUpgrade: () {},
      );
      return;
    }

    final nextUpgrade = GameConfig.oreUpgrades[level];
    final currentUpgrade = GameConfig.oreUpgrades[level - 1];
    final diff = nextUpgrade.income - currentUpgrade.income;

    UpgradeDialog.show(
      game.buildContext!,
      title: "${nextUpgrade.material} Ore",
      currentLevel: level,
      requirements: [],
      coinCost: nextUpgrade.cost.coins,
      energyCost: nextUpgrade.cost.energy,
      upgradeBenefit:
          "Lv. $level ➔ Lv. ${level + 1}\n${currentUpgrade.income} ➔ ${nextUpgrade.income} (+$diff) Coins/Sec${nextUpgrade.globalMultiplier > 1.0 ? '\n+${((nextUpgrade.globalMultiplier - 1) * 100).toInt()}% ALL Income' : ''}",
      onUpgrade: () {
        tryUpgrade(game.player);
      },
    );
  }

  /// Attempts to upgrade the ore mine using the resources of the provided entity.
  /// Returns true if the upgrade was successful.
  bool tryUpgrade(BaseEntity entity) {
    if (level >= GameConfig.oreUpgrades.length) return false;

    final nextUpgrade = GameConfig.oreUpgrades[level];

    // Resource Check & Deduction
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
      level++;
      hp = maxHp; // Heal to max HP on upgrade
      _updateVisuals();
      HapticManager.instance.medium();
      AudioManager.instance.playReward();
      return true;
    }

    return false;
  }
}

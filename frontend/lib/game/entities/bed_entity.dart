import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/entities/door_entity.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/widgets/game/upgrade_dialog.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/game/game_config.dart';
import 'package:dreamhunter/services/identity/auth_manager.dart';

/// A static bed building.
/// Characters cannot walk through the bed due to the 'building' category.
/// Shows a "Sleep" popup when the player is nearby and allows tapping to sleep.
class BedEntity extends BaseEntity with TapCallbacks {
  @override
  final String roomID;
  int level = 1;
  late final TextComponent _popupText;
  double _popupAlpha = 0.0;
  final double _fadeSpeed = 5.0; // Speed of the fade animation

  /// The entity that currently occupies this bed.
  BaseEntity? owner;
  bool get isOccupied => owner != null;

  /// The entity that is currently heading towards this bed.
  BaseEntity? reservedBy;

  /// The door belonging to this dorm room.
  DoorEntity? roomDoor;

  /// Hardcoded track of grid-center coordinates from spawn to this bed.
  final List<Vector2> predefinedPath = [];

  BedEntity({required super.position, required this.roomID})
    : super(size: Vector2.all(32), anchor: Anchor.topLeft) {
    addCategory('bed');
    addCategory('building');
    maxHp = 100.0;
    hp = maxHp;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load visual sprite
    final sprite = await Sprite.load('game/economy/bed-32x32.png');
    add(SpriteComponent(sprite: sprite, size: size));

    // Initialize popup text (Smaller font size: 8)
    _popupText = TextComponent(
      text: 'Sleep',
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x / 2, -4),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.transparent, // Start transparent
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
    );
    add(_popupText);
  }

  /// Called when a hunter (AI or Player) enters the bed.
  void occupy(BaseEntity hunter) {
    if (isOccupied) return;

    owner = hunter;
    hunter.currentBedLevel = level;

    // Close the dorm room door
    roomDoor?.close();

    // Remove popup text
    _popupText.removeFromParent();

    // If the owner is the player, handle player-specific logic
    if (hunter.hasCategory('player')) {
      MatchManager.instance.setCurrentRoom(roomID);
      game.joystick.removeFromParent();
    }
  }

  /// Attempts to upgrade the bed using the resources of the provided entity.
  /// Returns true if the upgrade was successful.
  bool tryUpgrade(BaseEntity entity) {
    if (level >= GameConfig.bedUpgrades.length) return false;

    final nextUpgrade = GameConfig.bedUpgrades[level];

    // 1. Check Requirements (Door level)
    if (nextUpgrade.requirementLabel != null) {
      final bool isMet = nextUpgrade.checkRequirement!(roomDoor);
      if (!isMet) return false;
    }

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
      level++;

      // Update visuals/income
      if (entity.hasCategory('player')) {
        MatchManager.instance.setIncomePerTick(nextUpgrade.income);
      }

      // Sync owner's bed level
      entity.currentBedLevel = level;

      HapticManager.instance.medium();
      AudioManager.instance.playClick();
      return true;
    }

    return false;
  }

  @override
  void destroy() {
    if (isDestroyed) return;
    
    // Kill the owner if one exists
    if (owner != null && owner!.hunterIndex != null) {
      MatchManager.instance.killHunter(owner!.hunterIndex!);
      owner!.destroy(); // Remove the hunter visual too
    }
    
    super.destroy();
  }

  @override
  void onTapUp(TapUpEvent event) {
    // Only allow player to interact with their OWN bed or an EMPTY bed
    if (owner != null && !owner!.hasCategory('player')) return;

    if (owner != null && owner!.hasCategory('player')) {
      final currentUpgrade = GameConfig.bedUpgrades[level - 1];
      final user = AuthManager.instance.currentUser;
      final String ownerName =
          (user?.displayName != null && user!.displayName!.isNotEmpty)
          ? user.displayName!
          : "Hunter";
      final String dialogTitle = "$ownerName's Bed";

      // Max Level Check
      if (level >= GameConfig.bedUpgrades.length) {
        UpgradeDialog.show(
          game.buildContext!,
          title: dialogTitle,
          currentLevel: level,
          requirements: [],
          coinCost: 0,
          upgradeBenefit: "MAXED OUT",
          isMaxLevel: true,
          onUpgrade: () {},
        );
        return;
      }

      final nextUpgrade = GameConfig.bedUpgrades[level];
      final List<UpgradeRequirement> reqs = [];

      if (nextUpgrade.requirementLabel != null) {
        final bool isMet = nextUpgrade.checkRequirement!(roomDoor);
        reqs.add(
          UpgradeRequirement(
            label: nextUpgrade.requirementLabel!,
            isMet: isMet,
          ),
        );
      }

      UpgradeDialog.show(
        game.buildContext!,
        title: dialogTitle,
        currentLevel: level,
        requirements: reqs,
        coinCost: nextUpgrade.cost.coins,
        energyCost: nextUpgrade.cost.energy,
        upgradeBenefit:
            "Lv. $level ➔ Lv. ${level + 1}\n${currentUpgrade.income} ➔ ${nextUpgrade.income} Coins/Sec",
        onUpgrade: () {
          tryUpgrade(owner!);
        },
      );
      return;
    }

    // Check distance to player
    final bedCenter = position + (size / 2);
    final playerPos = game.player.position;
    final distance = bedCenter.distanceTo(playerPos);

    if (distance < 48) {
      game.player.sleep(position);
      occupy(game.player);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isOccupied) return;

    // Check distance to player for popup visibility
    final bedCenter = position + (size / 2);
    final playerPos = game.player.position;
    final distance = bedCenter.distanceTo(playerPos);

    // Manual fade logic
    if (distance < 48) {
      _popupAlpha = (_popupAlpha + dt * _fadeSpeed).clamp(0.0, 1.0);
    } else {
      _popupAlpha = (_popupAlpha - dt * _fadeSpeed).clamp(0.0, 1.0);
    }

    // Update text color with the new alpha
    if (_popupAlpha > 0) {
      _popupText.textRenderer = TextPaint(
        style: TextStyle(
          color: Colors.white.withValues(alpha: _popupAlpha),
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: _popupAlpha),
              blurRadius: 4,
            ),
          ],
        ),
      );
    } else {
      _popupText.textRenderer = TextPaint(
        style: const TextStyle(color: Colors.transparent),
      );
    }
  }
}

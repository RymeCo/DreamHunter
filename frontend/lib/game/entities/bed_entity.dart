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
  final String roomID;
  int level = 1;
  late final TextComponent _popupText;
  double _popupAlpha = 0.0;
  final double _fadeSpeed = 5.0; // Speed of the fade animation
  bool _hasSlept = false;

  /// The door belonging to this dorm room.
  DoorEntity? roomDoor;

  BedEntity({required super.position, required this.roomID})
    : super(size: Vector2.all(32), anchor: Anchor.topLeft) {
    addCategory('bed');
    addCategory('building');
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

  @override
  void onTapUp(TapUpEvent event) {
    if (_hasSlept) {
      final currentUpgrade = GameConfig.bedUpgrades[level - 1];

      // NOTE: When Firebase/FastAPI integration is finalized:
      // 1. Fetch real username from ProfileManager.
      // 2. Default to "Hunter's Bed" if guest account or not logged in.
      // 3. Fallback to "Hunter's Bed" if the username exceeds reasonable length (Logic gap protection).
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
          final success = MatchManager.instance.spendResources(
            coins: nextUpgrade.cost.coins,
            energy: nextUpgrade.cost.energy,
          );
          if (success) {
            level++;
            MatchManager.instance.setIncomePerTick(nextUpgrade.income);
            HapticManager.instance.medium();
            AudioManager.instance.playClick();
          }
        },
      );
      return;
    }

    // Check distance to player
    final bedCenter = position + (size / 2);
    final playerPos = game.player.position;
    final distance = bedCenter.distanceTo(playerPos);

    if (distance < 48) {
      _hasSlept = true;
      game.player.sleep(position);

      // Claim this room in the MatchManager
      MatchManager.instance.setCurrentRoom(roomID);

      // Close the dorm room door
      roomDoor?.close();

      // Hide joystick permanently
      game.joystick.removeFromParent();

      // Remove popup text
      _popupText.removeFromParent();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hasSlept) return;

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

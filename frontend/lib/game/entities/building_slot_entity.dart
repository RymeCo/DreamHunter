import 'dart:developer' as developer;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/widgets/game/build_menu_dialog.dart';
import 'package:dreamhunter/game/entities/generator_entity.dart';
import 'package:dreamhunter/game/entities/turret_entity.dart';
import 'package:dreamhunter/game/entities/fridge_entity.dart';
import 'package:dreamhunter/game/entities/ore_entity.dart';
import 'package:dreamhunter/game/game_config.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';

/// A slot in a dorm room where building can be placed.
/// Only visible and interactive if the player has claimed the room.
class BuildingSlotEntity extends BaseEntity with TapCallbacks {
  @override
  final String roomID;
  late final Component _plusSign;
  bool _isVisible = false;

  BuildingSlotEntity({required super.position, required this.roomID})
    : super(size: Vector2.all(32), anchor: Anchor.topLeft) {
    addCategory('building_slot');
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Visual: A simple '+' icon built from rectangles (higher performance than text)
    _plusSign = PositionComponent(
      size: Vector2.all(14),
      anchor: Anchor.center,
      position: size / 2,
      children: [
        // Horizontal bar
        RectangleComponent(
          size: Vector2(14, 3),
          anchor: Anchor.center,
          position: Vector2(7, 7),
          paint: Paint()..color = Colors.white,
        ),
        // Vertical bar
        RectangleComponent(
          size: Vector2(3, 14),
          anchor: Anchor.center,
          position: Vector2(7, 7),
          paint: Paint()..color = Colors.white,
        ),
      ],
    );
    add(_plusSign);

    // Initial visibility check
    _updateVisibility();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateVisibility();

    if (_isVisible) {
      // Update opacity of the shapes
      final alpha = (game.slotOpacity * 255).toInt();
      for (final child in _plusSign.children.whereType<RectangleComponent>()) {
        child.paint.color = Colors.white.withAlpha(alpha);
      }
    }
  }

  void _updateVisibility() {
    final bool isMyRoom = MatchManager.instance.currentRoomID == roomID;

    if (isMyRoom != _isVisible) {
      _isVisible = isMyRoom;
    }
  }

  @override
  void renderTree(Canvas canvas) {
    if (!_isVisible) return;
    super.renderTree(canvas);
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!_isVisible) return;

    // RESTRICTION: Only allow building if the player is sleeping (in bed)
    if (!game.player.isSleeping) {
      AudioManager.instance.playClick();
      HapticManager.instance.light();

      // Feedback: Briefly inform the user they need to sleep first
      showCustomSnackBar(
        game.buildContext!,
        'You must get to bed before building!',
        type: SnackBarType.warning,
      );
      return;
    }

    AudioManager.instance.playClick();
    HapticManager.instance.light();

    // Check if a fridge already exists in this room
    final bool hasFridge = game.buildings.whereType<FridgeEntity>().any(
      (f) => f.roomID == roomID,
    );

    // Show Building Selection Menu
    BuildMenuDialog.show(
      game.buildContext!,
      hasFridge: hasFridge,
      onBuildSelected: (buildingId) {
        tryBuild(buildingId, owner: game.player);
      },
    );
  }

  /// Attempts to build a specific structure on this slot.
  /// If [owner] is provided, it checks and deducts resources from their wallet.
  /// Returns true if the build was successful.
  bool tryBuild(String buildingId, {BaseEntity? owner}) {
    // 1. Parse level and type
    int level = 1;
    String baseId = buildingId;
    if (buildingId.contains(':')) {
      final parts = buildingId.split(':');
      baseId = parts[0];
      level = int.tryParse(parts[1]) ?? 1;
    }

    // 2. Determine Cost
    int coinCost = 0;
    int energyCost = 0;

    if (baseId == 'generator') {
      coinCost = GameConfig.generatorUpgrades[level - 1].cost.coins;
      energyCost = GameConfig.generatorUpgrades[level - 1].cost.energy;
    } else if (baseId == 'turret') {
      coinCost = GameConfig.turretBuildCost;
    } else if (baseId == 'fridge') {
      energyCost = GameConfig.fridgeBuildCost;
    } else if (baseId == 'ore') {
      coinCost = GameConfig.oreUpgrades[level - 1].cost.coins;
      energyCost = GameConfig.oreUpgrades[level - 1].cost.energy;
    }

    // 3. Resource Check & Deduction (Fair Play Enforcement)
    if (owner != null) {
      if (owner.hasCategory('player')) {
        final success = MatchManager.instance.spendResources(
          coins: coinCost,
          energy: energyCost,
        );
        if (!success) return false;
      } else {
        if (owner.matchCoins >= coinCost && owner.matchEnergy >= energyCost) {
          owner.matchCoins -= coinCost;
          owner.matchEnergy -= energyCost;
        } else {
          return false;
        }
      }
    }

    // 4. Construction Logic
    BaseEntity? newBuilding;

    if (baseId == 'generator') {
      newBuilding = GeneratorEntity(
        position: position.clone(),
        roomID: roomID,
        level: level,
      );
    } else if (baseId == 'turret') {
      newBuilding = TurretEntity(
        position: position + (size / 2),
        roomID: roomID,
      );
    } else if (baseId == 'fridge') {
      // Restriction: Only one Fridge per room
      final bool alreadyHasFridge = game.buildings
          .whereType<FridgeEntity>()
          .any((f) => f.roomID == roomID);

      if (alreadyHasFridge) return false;

      newBuilding = FridgeEntity(
        position: position + (size / 2),
        roomID: roomID,
      );
    } else if (baseId == 'ore') {
      newBuilding = OreEntity(
        position: position.clone(),
        roomID: roomID,
        level: level,
      );
    }

    if (newBuilding != null) {
      developer.log(
        '[DEBUG] Construction: Built $baseId (Lv $level) in room $roomID (Owner: ${owner?.hunterIndex ?? 'Unknown'})',
      );
      game.world.add(newBuilding);
      removeFromParent();
      return true;
    }

    return false;
  }
}

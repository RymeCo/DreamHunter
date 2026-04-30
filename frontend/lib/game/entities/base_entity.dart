import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/game/components/floating_feedback.dart';
import 'package:dreamhunter/game/entities/ore_entity.dart';
import 'package:dreamhunter/game/game_config.dart';

/// The foundational class for all game objects (players, monsters, furniture, etc.)
/// Adheres to the Composition & Behavior Architecture mandate.
abstract class BaseEntity extends PositionComponent
    with CollisionCallbacks, HasGameReference<DreamHunterGame> {
  /// Tags for categorizing entities (e.g., 'player', 'monster', 'obstacle')
  final Set<String> categories = {};

  // In-match Economy
  int _localMatchCoins = 0;
  int _localMatchEnergy = 0;

  int get matchCoins {
    if (hasCategory('player')) return MatchManager.instance.matchCoins;
    return _localMatchCoins;
  }

  set matchCoins(int value) {
    if (hasCategory('player')) {
      MatchManager.instance.syncPlayerWallet(
        value,
        MatchManager.instance.matchEnergy,
      );
    } else {
      _localMatchCoins = value;
    }
  }

  int get matchEnergy {
    if (hasCategory('player')) return MatchManager.instance.matchEnergy;
    return _localMatchEnergy;
  }

  set matchEnergy(int value) {
    if (hasCategory('player')) {
      MatchManager.instance.syncPlayerWallet(
        MatchManager.instance.matchCoins,
        value,
      );
    } else {
      _localMatchEnergy = value;
    }
  }

  // Sleeping state
  bool isSleeping = false;

  /// Index of the hunter (0 for player, 1+ for AI).
  /// Null if this is not a hunter entity.
  int? hunterIndex;

  // Health System
  double hp = 1.0;
  double maxHp = 1.0;
  bool isDestroyed = false;

  int _lastCoinTick = 0;
  int _lastEnergyTick = 0;

  /// The level of the bed this entity is currently occupying.
  int? currentBedLevel;

  /// Gets the room ID this entity is associated with.
  String get roomID {
    if (hasCategory('player')) return MatchManager.instance.currentRoomID;
    return '';
  }

  BaseEntity({super.position, super.size, super.anchor});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Standard Hitbox: 75% width, 25% height at the feet.
    add(
      RectangleHitbox(
        size: Vector2(size.x * 0.75, size.y * 0.25),
        position: Vector2(size.x * 0.125, size.y * 0.75),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    final manager = MatchManager.instance;

    // 1. Coin Generation (1 Tick / 1 Second)
    if (manager.coinTickCount > _lastCoinTick) {
      _lastCoinTick = manager.coinTickCount;

      final income = incomePerTick;
      if (income > 0) {
        matchCoins += income;

        // Visual Feedback for Coins only shows when sleeping
        if (isSleeping) {
          game.world.add(
            FloatingFeedback(
              label: '+$income',
              isCoin: true,
              color: Colors.amberAccent,
              position: position + Vector2(size.x * 0.7, 0), // Side offset
            ),
          );
        }
      }

      // Visual Feedback for Zzz (Every 3 coin ticks, only when sleeping)
      if (isSleeping && _lastCoinTick % 3 == 0) {
        game.world.add(
          FloatingFeedback(
            label: math.Random().nextBool() ? 'z' : 'Z',
            color: Colors.white,
            position: position + Vector2(size.x * 0.3, 0), // Other side offset
          ),
        );
      }
    }

    // 2. Energy Generation (1 Tick / 2 Seconds)
    if (manager.energyTickCount > _lastEnergyTick) {
      _lastEnergyTick = manager.energyTickCount;

      final energy = energyIncomePerTick;
      if (energy > 0) {
        matchEnergy += energy;
      }
    }
  }

  /// The number of coins this entity earns per tick.
  int get incomePerTick {
    int baseIncome = 0;
    if (currentBedLevel != null) {
      // 1. Bed Income
      final level = currentBedLevel!;
      if (level > 0 && level <= GameConfig.bedUpgrades.length) {
        baseIncome = GameConfig.bedUpgrades[level - 1].income;
      }
    } else {
      // Fallback/Default
      if (hasCategory('player')) {
        baseIncome = MatchManager.instance.incomePerTick;
      } else if (hasCategory('ai_hunter')) {
        baseIncome = 1;
      }
    }

    // 2. Ore Income (from self)
    if (this is OreEntity) {
      baseIncome = (this as OreEntity).incomePerTick;
    }

    // 3. Apply Room Multiplier (e.g., Level 5 Ore)
    double multiplier = 1.0;
    final myRoom = roomID;
    if (myRoom.isNotEmpty) {
      final ores = game.world.children.whereType<OreEntity>().where(
        (ore) => ore.roomID == myRoom,
      );

      for (final ore in ores) {
        if (ore.level == 5) {
          multiplier *= 1.5;
        }
      }
    }

    return (baseIncome * multiplier).floor();
  }

  /// The number of energy this entity earns per tick.
  int get energyIncomePerTick {
    if (hasCategory('player')) return MatchManager.instance.energyIncomePerTick;
    return 0;
  }

  @override
  void onMount() {
    super.onMount();
    if (categories.contains('monster')) {
      game.monsters.add(this);
    }
    if (categories.contains('building')) {
      game.registerBuilding(this);
    }
    if (categories.contains('building_slot')) {
      game.registerBuildingSlot(this);
    }
  }

  @override
  void onRemove() {
    if (categories.contains('monster')) {
      game.monsters.remove(this);
    }
    if (categories.contains('building')) {
      game.unregisterBuilding(this);
    }
    if (categories.contains('building_slot')) {
      game.unregisterBuildingSlot(this);
    }
    super.onRemove();
  }

  /// Helper to check if this entity has a specific category.
  bool hasCategory(String category) => categories.contains(category);

  /// Helper to add a category.
  void addCategory(String category) {
    categories.add(category);
    if (isMounted) {
      if (category == 'monster') {
        game.monsters.add(this);
      }
      if (category == 'building') {
        game.registerBuilding(this);
      }
      if (category == 'building_slot') {
        game.registerBuildingSlot(this);
      }
    }
  }

  /// Reduces health and handles destruction if health reaches zero.
  void takeDamage(double amount) {
    if (isDestroyed) return;
    hp = (hp - amount).clamp(0, maxHp);
    if (hp <= 0) {
      destroy();
    }
  }

  /// Handles the destruction of this entity.
  void destroy() {
    if (isDestroyed) return;
    isDestroyed = true;
    removeFromParent();
  }
}

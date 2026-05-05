import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/game/components/floating_feedback.dart';
import 'package:dreamhunter/game/entities/ore_entity.dart';
import 'package:dreamhunter/game/entities/generator_entity.dart';
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

  /// Whether this entity is currently being repaired (manual repair mode).
  bool isBeingRepaired = false;

  /// Whether this entity is currently stunned (disabled).
  bool isStunned = false;
  double stunTimer = 0.0;

  /// Cooldown for the manual repair tool (20 seconds).
  double repairCooldown = 0;

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

  /// Gets the current level of this entity (for AI targeting decisions).
  int get entityLevel => 0;

  /// Gets the total coin value of this building (for selling).
  int get sellValueCoins => 0;

  /// Gets the total energy value of this building (for selling).
  int get sellValueEnergy => 0;

  BaseEntity({super.position, super.size, super.anchor});

  /// Refunds 20% of the building's value and replaces it with a slot.
  /// If [owner] is provided, the refund goes to their wallet.
  void sell({BaseEntity? owner}) {
    if (isDestroyed) return;

    // MANDATE: Doors and Beds CANNOT be sold.
    if (hasCategory('door') || hasCategory('bed')) {
      debugPrint(
        '[SAFETY] Blocked attempt to sell core infrastructure: $runtimeType',
      );
      return;
    }

    // 1. Calculate Refund (20%)
    final refundCoins = (sellValueCoins * 0.2).floor();
    final refundEnergy = (sellValueEnergy * 0.2).floor();

    // 2. Add Resources to Owner (Fair Play Enforcement)
    if (owner != null) {
      if (owner.hasCategory('player')) {
        if (refundCoins > 0) {
          MatchManager.instance.updateMatchCoins(refundCoins);
        }
        if (refundEnergy > 0) {
          MatchManager.instance.updateMatchEnergy(refundEnergy);
        }
      } else {
        owner.matchCoins += refundCoins;
        owner.matchEnergy += refundEnergy;
      }
    }

    // 3. Spawn Floating Feedback
    if (refundCoins > 0 || refundEnergy > 0) {
      game.world.add(
        FloatingFeedback(
          label:
              "${refundCoins > 0 ? '+$refundCoins ' : ''}${refundEnergy > 0 ? '+$refundEnergy' : ''}",
          color: refundCoins > 0 ? Colors.amberAccent : Colors.cyanAccent,
          position: position.clone(),
        ),
      );
    }

    // 4. Replace with Slot
    final slot = game.spawnBuildingSlot(position.clone(), roomID);
    game.world.add(slot);

    // 5. Remove Self
    destroy();
  }

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
    if (isDestroyed) return;

    // Stun logic
    if (isStunned) {
      stunTimer -= dt;
      if (stunTimer <= 0) {
        isStunned = false;
        stunTimer = 0;
      }
    }

    if (repairCooldown > 0) {
      repairCooldown = (repairCooldown - dt).clamp(
        0,
        GameConfig.repairCooldown,
      );
    }

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

      // Sync energy income rate to MatchManager for HUD/UX if this is the player
      if (hasCategory('player')) {
        MatchManager.instance.setEnergyIncomePerTick(energy);
      }
    }
  }

  /// The number of coins this entity earns per tick.
  int get incomePerTick {
    // 0. Dead hunters earn nothing
    if (hunterIndex != null &&
        !MatchManager.instance.isHunterAlive(hunterIndex!)) {
      return 0;
    }

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
      // PERFORMANCE OPTIMIZATION: Use cached buildings list
      final ores = game.getBuildingsInRoom(myRoom).whereType<OreEntity>();

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
    // 0. Dead hunters earn nothing
    if (hunterIndex != null &&
        !MatchManager.instance.isHunterAlive(hunterIndex!)) {
      return 0;
    }

    final myRoom = roomID;
    if (myRoom.isEmpty) return 0;

    // PERFORMANCE OPTIMIZATION: Use game's cached buildings list to find generators in this room
    final generators = game
        .getBuildingsInRoom(myRoom)
        .whereType<GeneratorEntity>();

    int income = 0;
    for (final gen in generators) {
      // Generators are 1-indexed for level, GameConfig is 0-indexed
      if (gen.level > 0 && gen.level <= GameConfig.generatorUpgrades.length) {
        income += GameConfig.generatorUpgrades[gen.level - 1].income;
      }
    }

    return income;
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

    // Core Infrastructure Unregistration
    if (categories.contains('door')) {
      game.unregisterDoor(this as dynamic);
    }
    if (categories.contains('bed')) {
      game.unregisterBed(this as dynamic);
    }

    super.onRemove();
  }

  /// Stuns this entity for a specific duration.
  void stun(double duration) {
    if (isDestroyed) return;
    isStunned = true;
    stunTimer = duration;
    isBeingRepaired = false; // Stun stops repair!
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
  void takeDamage(double amount, {bool isPlayerOwned = false}) {
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

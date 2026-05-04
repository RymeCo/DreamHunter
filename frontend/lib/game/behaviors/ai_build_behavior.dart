import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:dreamhunter/game/entities/hunter_ai_entity.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/game/entities/building_slot_entity.dart';
import 'package:dreamhunter/game/entities/generator_entity.dart';
import 'package:dreamhunter/game/entities/turret_entity.dart';
import 'package:dreamhunter/game/entities/fridge_entity.dart';
import 'package:dreamhunter/game/entities/bed_entity.dart';
import 'package:dreamhunter/game/entities/door_entity.dart';
import 'package:dreamhunter/game/game_config.dart';

/// Handles building and upgrading logic for AI hunters.
/// Obeys personality traits and speed constraints.
class AIBuildBehavior extends Component
    with ParentIsA<HunterAIEntity>, HasGameReference<DreamHunterGame> {
  late Timer _timer;
  final math.Random _random = math.Random();

  @override
  void onMount() {
    super.onMount();
    _resetTimer();
  }

  /// Resets the check timer based on the AI's speed trait.
  void _resetTimer() {
    double interval;
    if (parent.speed == AISpeed.fast) {
      // Fast AIs check frequently (0.5s to 1s)
      interval = 0.5 + _random.nextDouble() * 0.5;
    } else if (parent.speed == AISpeed.slow) {
      // Slow AIs check randomly (3s to 10s)
      interval = 3.0 + _random.nextDouble() * 7.0;
    } else {
      // Glacier AIs check very rarely (15s to 30s)
      interval = 15.0 + _random.nextDouble() * 15.0;
    }

    // Dumb personalities double the interval again!
    if (parent.personality == AIPersonality.dumb) {
      interval *= 2.0;
    }

    _timer = Timer(interval, onTick: _checkBuild, repeat: true);
  }

  /// Logic to decide what to build or upgrade.
  void _checkBuild() {
    if (!parent.isSleeping) return;

    // Dumb Personality Check: 50% chance to just "forget" to check for upgrades this tick
    if (parent.personality == AIPersonality.dumb && _random.nextBool()) {
      return;
    }

    final door = parent.targetBed.roomDoor;
    final bed = parent.targetBed;

    // --- PANIC CHECK: Is my home being destroyed? ---
    bool isPanic = false;
    if (door != null && !door.isDestroyed && door.hp / door.maxHp < 0.4) {
      isPanic = true;
    } else if (bed.hp / bed.maxHp < 0.4) {
      isPanic = true;
    }

    if (isPanic) {
      _handlePanic(door, bed);
      return;
    }

    // --- STRATEGIC DISMANTLE: Deny XP or recover coins ---
    _checkStrategicDismantle();

    // --- BAITER SPECIAL LOGIC: Proactive "Clutch" Repair ---
    if (parent.personality == AIPersonality.baiter &&
        door != null &&
        !door.isDestroyed) {
      // Baiters wait until the door is ALMOST dead (e.g., < 15% HP)
      // Then they upgrade it to instantly heal it, making the monster waste the most time.
      if (door.hp / door.maxHp < 0.15 && door.hp > 1.0) {
        if (door.tryUpgrade(parent)) {
          _resetTimer();
          return;
        }
      }
    }

    // --- SMART PROGRESSION: Check Bed Requirements Proactively ---
    if (bed.level < GameConfig.bedUpgrades.length) {
      final nextBedUpgrade = GameConfig.bedUpgrades[bed.level];
      if (nextBedUpgrade.requirementLabel != null &&
          !nextBedUpgrade.checkRequirement!(door)) {
        // We are blocked by a door requirement! Try to upgrade the door instead.
        if (door != null && door.totalUpgrades < 15) {
          if (door.tryUpgrade(parent)) {
            _resetTimer();
            return;
          }
        }
      }
    }

    // --- PRIORITY 1: Personality-Driven Progression ---
    switch (parent.personality) {
      case AIPersonality.smart:
        if (_doSmartCheck()) return;
        break;
      case AIPersonality.baiter:
        if (_doBaiterCheck()) return;
        break;
      case AIPersonality.defense:
        if (_doDefenseCheck()) return;
        break;
      case AIPersonality.offense:
        if (_doOffenseCheck()) return;
        break;
      case AIPersonality.randos:
        if (_random.nextBool()) {
          if (_doDefenseCheck()) return;
        } else {
          if (_doOffenseCheck()) return;
        }
        break;
      case AIPersonality.dumb:
        if (_random.nextDouble() < 0.2) {
          // Even lower chance to build
          if (_random.nextBool()) {
            if (_doDefenseCheck()) return;
          } else {
            if (_doOffenseCheck()) return;
          }
        }
        break;
    }

    // --- PRIORITY 2: Fill empty slots if nothing else to do ---
    _checkNewConstruction();
  }

  void _handlePanic(DoorEntity? door, BedEntity bed) {
    // PANIC UPGRADE: Try to save the door or bed to get that instant heal!
    if (door != null && !door.isDestroyed && door.hp < door.maxHp) {
      if (door.tryUpgrade(parent)) {
        _resetTimer();
        return;
      }
    }
    if (bed.hp < bed.maxHp) {
      if (bed.tryUpgrade(parent)) {
        _resetTimer();
        return;
      }
    }

    // PANIC OFFENSE: Build or Upgrade Turrets to kill the intruder
    final myTurrets = game.turrets
        .whereType<TurretEntity>()
        .where((t) => parent.targetBed.roomID == t.roomID)
        .toList();

    for (final turret in myTurrets) {
      if (turret.level < 9) {
        turret.tryUpgrade(parent);
      }
    }

    // If we have empty slots, fill them with Turrets NOW
    final mySlots = game.buildingSlots
        .whereType<BuildingSlotEntity>()
        .where((slot) => slot.roomID == parent.targetBed.roomID)
        .toList();

    if (mySlots.isNotEmpty && parent.matchCoins >= GameConfig.turretBuildCost) {
      final slot = mySlots[_random.nextInt(mySlots.length)];
      slot.tryBuild('turret', owner: parent);
    }

    _timer.limit = 0.5;
  }

  void _checkStrategicDismantle() {
    // Only check for dismantling occasionally to save cycles
    if (_random.nextDouble() > 0.3) return;

    final myBuildings = game.getBuildingsInRoom(parent.targetBed.roomID);
    if (myBuildings.isEmpty) return;

    for (final building in myBuildings) {
      if (building is DoorEntity || building is BedEntity) continue; // Never sell core infrastructure

      bool shouldDismantle = false;

      // 1. HP DENIAL: If a building is about to die and being attacked, sell it to deny XP and get coins back
      if (building.hp / building.maxHp < 0.15) {
        final monstersNearby = game.monsters.any((m) => m.center.distanceTo(building.center) < 80);
        if (monstersNearby) {
          // Deny destruction XP!
          if (parent.personality == AIPersonality.smart || 
              parent.personality == AIPersonality.baiter || 
              _random.nextBool()) {
            shouldDismantle = true;
          }
        }
      }

      // 2. OPTIMIZATION: If we are low on coins but have energy (or vice-versa) and need a critical upgrade
      if (!shouldDismantle && parent.personality == AIPersonality.smart) {
         // If we need coins for a Bed upgrade and have many generators
         if (parent.matchCoins < 50 && building is GeneratorEntity) {
            final genCount = myBuildings.whereType<GeneratorEntity>().length;
            if (genCount > 2) shouldDismantle = true;
         }
      }

      if (shouldDismantle) {
        debugPrint('[AI] Strategic Dismantle: AI ${parent.hunterIndex} selling ${building.runtimeType} in room ${parent.targetBed.roomID}');
        building.sell(owner: parent);
        _resetTimer();
        return;
      }
    }
  }

  /// Defense-focused logic: Prioritize Door and Turrets.
  bool _doDefenseCheck() {
    final door = parent.targetBed.roomDoor;
    final bed = parent.targetBed;

    // Defense AI: Always keeps Door level >= Bed level
    if (door != null && door.totalUpgrades < bed.level) {
      if (door.tryUpgrade(parent)) {
        _resetTimer();
        return true;
      }
    }

    // Defense AI: Upgrades existing Turrets before Bed if they are behind
    final myTurrets = game.turrets
        .whereType<TurretEntity>()
        .where((t) => parent.targetBed.roomID == t.roomID)
        .toList();

    for (final turret in myTurrets) {
      if (turret.level < bed.level) {
        if (parent.matchCoins >= (turret.level * 150)) {
           // We check cost here to avoid spamming tryUpgrade and wasting cycles
           turret.tryUpgrade(parent);
           _resetTimer();
           return true;
        }
      }
    }

    // Finally, upgrade Bed
    if (bed.tryUpgrade(parent)) {
      _resetTimer();
      return true;
    }

    return false;
  }

  /// Offense-focused logic: Prioritize Bed and Generators.
  bool _doOffenseCheck() {
    final bed = parent.targetBed;

    // Offense AI: Upgrades Bed first and foremost
    if (bed.tryUpgrade(parent)) {
      _resetTimer();
      return true;
    }

    // Proactive Generator Requirement Check
    final myGenerators = game.buildings
        .whereType<GeneratorEntity>()
        .where((g) => g.roomID == bed.roomID)
        .toList();

    for (final generator in myGenerators) {
      if (generator.level < GameConfig.generatorUpgrades.length) {
        final nextGenUpgrade = GameConfig.generatorUpgrades[generator.level];
        if (nextGenUpgrade.requirementLabel != null) {
          // Generators usually require a Turret level
          final myTurrets = game.turrets.whereType<TurretEntity>()
              .where((t) => t.roomID == bed.roomID).toList();
          int maxTurretLv = myTurrets.isEmpty ? 0 : myTurrets.map((t) => t.level).reduce(math.max);

          final bool isMet = nextGenUpgrade.checkRequirement!(maxTurretLv);
          if (!isMet) {
            // Blocked by turret requirement! Build or upgrade a turret.
            if (myTurrets.isEmpty) {
              _buildNewTurret();
              return true;
            } else {
              // Upgrade the lowest turret to help meet requirement
              myTurrets.sort((a, b) => a.level.compareTo(b.level));
              myTurrets[0].tryUpgrade(parent);
              _resetTimer();
              return true;
            }
          }
        }

        if (generator.tryUpgrade(parent)) {
          _resetTimer();
          return true;
        }
      }
    }

    return false;
  }

  void _buildNewTurret() {
    final mySlots = game.buildingSlots
        .whereType<BuildingSlotEntity>()
        .where((slot) => slot.roomID == parent.targetBed.roomID)
        .toList();
    if (mySlots.isNotEmpty && parent.matchCoins >= GameConfig.turretBuildCost) {
      final slot = mySlots[_random.nextInt(mySlots.length)];
      if (slot.tryBuild('turret', owner: parent)) {
        _resetTimer();
      }
    }
  }

  /// Finds an empty slot in the AI's room and builds something.
  void _checkNewConstruction() {
    final mySlots = game.buildingSlots
        .whereType<BuildingSlotEntity>()
        .where((slot) => slot.roomID == parent.targetBed.roomID)
        .toList();

    if (mySlots.isEmpty) return;

    // --- PHASE 1: CHECK FOR FRIDGE (ENERGY RESOURCE) ---
    final bool alreadyHasFridge = game.world.children
        .whereType<FridgeEntity>()
        .any((f) => f.roomID == parent.targetBed.roomID);

    if (!alreadyHasFridge && parent.matchEnergy >= GameConfig.fridgeBuildCost) {
      bool shouldBuildFridge = false;
      if (parent.personality == AIPersonality.defense) {
        shouldBuildFridge = true;
      } else if (_random.nextDouble() < 0.3) {
        // 30% chance for other personalities
        shouldBuildFridge = true;
      }

      if (shouldBuildFridge) {
        final slot = mySlots[_random.nextInt(mySlots.length)];
        if (slot.tryBuild('fridge', owner: parent)) {
          _resetTimer();
          return;
        }
      }
    }

    // --- PHASE 2: CHECK FOR COIN BUILDINGS ---
    // Pick a random slot
    final slot = mySlots[_random.nextInt(mySlots.length)];

    String buildingToBuild;

    switch (parent.personality) {
      case AIPersonality.smart:
        // Smart AIs prioritize whatever they have less of
        final turretCount = game.world.children
            .whereType<TurretEntity>()
            .where((t) => t.roomID == parent.targetBed.roomID)
            .length;
        final genCount = game.world.children
            .whereType<GeneratorEntity>()
            .where((g) => g.roomID == parent.targetBed.roomID)
            .length;
        if (turretCount <= genCount) {
          buildingToBuild = 'turret';
        } else {
          buildingToBuild = 'generator';
        }
        break;
      case AIPersonality.baiter:
        // Baiters rush economy
        buildingToBuild = 'generator';
        break;
      case AIPersonality.defense:
        buildingToBuild = 'turret';
        break;
      case AIPersonality.offense:
        buildingToBuild = 'generator';
        break;
      case AIPersonality.randos:
        buildingToBuild = _random.nextBool() ? 'turret' : 'generator';
        break;
      case AIPersonality.dumb:
        // 20% chance to build something
        if (_random.nextDouble() > 0.2) return;
        buildingToBuild = _random.nextBool() ? 'turret' : 'generator';
        break;
    }

    if (slot.tryBuild(buildingToBuild, owner: parent)) {
      _resetTimer();
    }
  }

  /// Smart logic: Highly efficient, balances everything, tries to max out.
  bool _doSmartCheck() {
    final bed = parent.targetBed;
    final door = bed.roomDoor;

    // 1. Core Economy: Keep Bed as high as possible
    if (bed.tryUpgrade(parent)) {
      _resetTimer();
      return true;
    }

    // 2. Proactive Defense: Door should be at least 1.5x Bed level (e.g. Bed Lv4 -> Door Wood V)
    if (door != null && door.totalUpgrades < bed.level * 1.5) {
      if (door.tryUpgrade(parent)) {
        _resetTimer();
        return true;
      }
    }

    // 3. Energy check
    final myGenerators = game.world.children
        .whereType<GeneratorEntity>()
        .where((g) => g.roomID == bed.roomID)
        .toList();
    if (myGenerators.isEmpty && parent.matchCoins >= 200) {
      _buildInEmptySlot('generator');
      return true;
    }

    // 4. Turret check
    final myTurrets = game.world.children
        .whereType<TurretEntity>()
        .where((t) => t.roomID == bed.roomID)
        .toList();
    for (final turret in myTurrets) {
      if (turret.level < bed.level) {
        // We don't check return value because it's a Future<bool>
        // and we are in a synchronous tick.
        turret.tryUpgrade(parent);
        _resetTimer();
        return true;
      }
    }

    return false;
  }

  /// Baiter logic: Hoards coins, focuses on economy, only upgrades door defensively.
  bool _doBaiterCheck() {
    final bed = parent.targetBed;
    // Baiters RUSH bed level above all else to hoard coins.
    if (bed.tryUpgrade(parent)) {
      _resetTimer();
      return true;
    }

    // Only upgrade door if absolutely necessary or if bed is high level
    final door = bed.roomDoor;
    if (door != null && bed.level > 4 && door.totalUpgrades < 3) {
      if (door.tryUpgrade(parent)) {
        _resetTimer();
        return true;
      }
    }

    return false;
  }

  void _buildInEmptySlot(String type) {
    final mySlots = game.buildingSlots
        .whereType<BuildingSlotEntity>()
        .where((slot) => slot.roomID == parent.targetBed.roomID)
        .toList();
    if (mySlots.isNotEmpty) {
      final slot = mySlots[_random.nextInt(mySlots.length)];
      if (slot.tryBuild(type, owner: parent)) {
        _resetTimer();
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer.update(dt);
  }
}

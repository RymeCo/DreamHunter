import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:dreamhunter/game/entities/hunter_ai_entity.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/game/entities/building_slot_entity.dart';
import 'package:dreamhunter/game/entities/generator_entity.dart';
import 'package:dreamhunter/game/entities/turret_entity.dart';
import 'package:dreamhunter/game/entities/fridge_entity.dart';
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
    } else {
      // Slow AIs check very randomly (3s to 10s)
      interval = 3.0 + _random.nextDouble() * 7.0;
    }
    _timer = Timer(interval, onTick: _checkBuild, repeat: true);
  }

  /// Logic to decide what to build or upgrade.
  void _checkBuild() {
    if (!parent.isSleeping) return;

    // --- PRIORITY 1: Core Economy (Bed Lv1 -> Lv3) ---
    if (parent.targetBed.level == 1) {
      if (parent.targetBed.tryUpgrade(parent)) {
        _resetTimer();
        return;
      }
    }

    final door = parent.targetBed.roomDoor;
    if (parent.targetBed.level == 2 &&
        door != null &&
        door.totalUpgrades == 0) {
      if (door.tryUpgrade(parent)) {
        _resetTimer();
        return;
      }
    }

    if (parent.targetBed.level == 2 &&
        door != null &&
        door.totalUpgrades >= 1) {
      if (parent.targetBed.tryUpgrade(parent)) {
        _resetTimer();
        return;
      }
    }

    // --- PRIORITY 2: Personality-Driven Progression ---
    switch (parent.personality) {
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
    }

    // --- PRIORITY 3: Fill empty slots if nothing else to do ---
    _checkNewConstruction();
  }

  /// Defense-focused logic: Prioritize Door and Turrets.
  bool _doDefenseCheck() {
    final door = parent.targetBed.roomDoor;
    // Upgrade Door if it's lagging behind Bed
    if (door != null && door.totalUpgrades < parent.targetBed.level * 1.5) {
      if (door.tryUpgrade(parent)) {
        _resetTimer();
        return true;
      }
    }

    // Upgrade existing Turrets
    final myTurrets = game.world.children
        .whereType<TurretEntity>()
        .where((t) => parent.targetBed.roomID == _getRoomIDOfTurret(t))
        .toList();

    for (final turret in myTurrets) {
      if (turret.level < parent.targetBed.level) {
        // AI doesn't need to await Future<bool>, they just try.
        turret.tryUpgrade(parent);
        _resetTimer();
        return true;
      }
    }

    return false;
  }

  /// Offense-focused logic: Prioritize Bed and Generators.
  bool _doOffenseCheck() {
    // Upgrade Bed
    if (parent.targetBed.tryUpgrade(parent)) {
      _resetTimer();
      return true;
    }

    // Upgrade existing Generators
    final myGenerators = game.world.children
        .whereType<GeneratorEntity>()
        .where((g) => g.roomID == parent.targetBed.roomID)
        .toList();

    for (final generator in myGenerators) {
      if (generator.level < parent.targetBed.level) {
        if (generator.tryUpgrade(parent)) {
          _resetTimer();
          return true;
        }
      }
    }

    return false;
  }

  /// Helper to find the roomID of a turret.
  String _getRoomIDOfTurret(TurretEntity turret) {
    return turret.roomID;
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
        parent.matchEnergy -= GameConfig.fridgeBuildCost;
        slot.tryBuild('fridge');
        _resetTimer();
        return;
      }
    }

    // --- PHASE 2: CHECK FOR COIN BUILDINGS ---
    // Pick a random slot
    final slot = mySlots[_random.nextInt(mySlots.length)];

    String buildingToBuild;
    int cost = 0;

    switch (parent.personality) {
      case AIPersonality.defense:
        buildingToBuild = 'turret';
        cost = GameConfig.turretBuildCost;
        break;
      case AIPersonality.offense:
        buildingToBuild = 'generator';
        cost = GameConfig.generatorUpgrades[0].cost.coins;
        break;
      case AIPersonality.randos:
        if (_random.nextBool()) {
          buildingToBuild = 'turret';
          cost = GameConfig.turretBuildCost;
        } else {
          buildingToBuild = 'generator';
          cost = GameConfig.generatorUpgrades[0].cost.coins;
        }
        break;
    }

    if (parent.matchCoins >= cost) {
      parent.matchCoins -= cost;
      slot.tryBuild(buildingToBuild);
      _resetTimer();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer.update(dt);
  }
}

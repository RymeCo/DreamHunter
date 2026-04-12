import 'package:flame/components.dart';
import '../haunted_dorm_game.dart';
import '../level/collision_block.dart';
import '../objects/bed.dart';
import '../objects/building_slot.dart';
import '../objects/turret.dart';
import '../objects/generator.dart';

enum AIHunterState { wandering, claiming, sleeping }

class AIHunter extends SpriteComponent with HasGameReference<HauntedDormGame> {
  final String characterType;
  final Vector2 spriteSize;
  double speed = 70.0;
  bool isMovingBack = false;

  AIHunterState _state = AIHunterState.wandering;
  List<CollisionBlock> collisionBlocks = [];
  List<Bed> beds = [];
  Bed? targetBed;

  double energy = 0;
  double coins = 0;
  double _economyTimer = 0;
  double _incomeTimer = 0;

  AIHunter({required this.characterType, Vector2? size})
    : spriteSize = size ?? Vector2(32, 48);

  @override
  Future<void> onLoad() async {
    final fileName = 'game/characters/${characterType}_front-32x48.png';
    sprite = await game.loadSprite(fileName);
    size = spriteSize;
    anchor = Anchor.center;
    priority = 5;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_state == AIHunterState.sleeping) {
      _handleEconomy(dt);
      return;
    }

    if (_state == AIHunterState.claiming && targetBed != null) {
      // AI Vision: Check if the door to their target room is closed
      final myDoor = game.level.allDoors.firstWhere(
        (d) => d.roomID == targetBed!.roomID,
        orElse: () => game.level.allDoors.first,
      );
      if (!myDoor.isOpen && game.player.currentBed == targetBed) {
        yieldBed();
        return;
      }
      _moveToTarget(dt);
    }
  }

  void _handleEconomy(double dt) {
    if (game.isGracePeriod) return;

    _incomeTimer += dt;
    if (_incomeTimer >= 0.5) {
      _incomeTimer = 0;
      coins += 1;
    }

    _economyTimer += dt;
    if (_economyTimer >= 5.0) {
      _economyTimer = 0;
      _decideWhatToBuild();
    }
  }

  void _decideWhatToBuild() {
    if (targetBed == null) return;

    final myDoor = game.level.allDoors.firstWhere(
      (d) => d.roomID == targetBed!.roomID,
      orElse: () => game.level.allDoors.first,
    );

    // Repair costs coins
    if (coins >= 50 && myDoor.currentHealth < myDoor.maxHealth) {
      coins -= 10;
      myDoor.repair(50.0);
      return;
    }

    // Build Generator costs COINS
    if (coins >= 50) {
      final emptySlot = game.level.allSlots.firstWhere(
        (s) => s.roomID == targetBed!.roomID && !s.isOccupied,
        orElse: () =>
            BuildingSlot(position: Vector2.zero(), size: Vector2.zero()),
      );

      if (emptySlot.roomID != -1) {
        game.level.add(
          Generator(
            position: emptySlot.position.clone(),
            size: emptySlot.size.clone(),
            level: 1,
            onProduce: (amount) => energy += amount,
          ),
        );
        emptySlot.isOccupied = true;
        coins -= 50;
        return;
      }
    }

    // Build Turret costs ENERGY
    if (energy >= 10) {
      final emptySlot = game.level.allSlots.firstWhere(
        (s) => s.roomID == targetBed!.roomID && !s.isOccupied,
        orElse: () =>
            BuildingSlot(position: Vector2.zero(), size: Vector2.zero()),
      );

      if (emptySlot.roomID != -1) {
        game.level.add(
          Turret(
            position: emptySlot.position.clone(),
            size: emptySlot.size.clone(),
            level: 1,
          ),
        );
        emptySlot.isOccupied = true;
        energy -= 10;
      }
    }
  }

  void _moveToTarget(double dt) {
    if (targetBed == null) return;
    final targetPos = targetBed!.position + (targetBed!.size / 2);
    final direction = targetPos - position;
    if (direction.length < 5) {
      _enterBed();
      return;
    }
    position += direction.normalized() * speed * dt;
  }

  void _enterBed() {
    if (targetBed != null) {
      _state = AIHunterState.sleeping;
      position = targetBed!.position + (targetBed!.size / 2);
      for (final door in game.level.allDoors) {
        if (door.roomID == targetBed!.roomID) {
          door.closeDoor();
          break;
        }
      }
      _updateSprite();
    }
  }

  void yieldBed() {
    _state = AIHunterState.wandering;
    targetBed = null;
  }

  void setTargetBed(Bed bed) {
    targetBed = bed;
    _state = AIHunterState.claiming;
  }

  Future<void> _updateSprite() async {
    final fileName = 'game/characters/${characterType}_front-32x48.png';
    if (_state == AIHunterState.sleeping) {
      sprite = await game.loadSprite(
        fileName,
        srcPosition: Vector2(0, 0),
        srcSize: Vector2(32, 24),
      );
      size = Vector2(32, 24);
      return;
    }
    size = spriteSize;
    sprite = await game.loadSprite(fileName);
  }
}

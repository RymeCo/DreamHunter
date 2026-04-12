import 'dart:async';
import 'dart:collection';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../actors/player.dart';
import '../actors/ai_hunter.dart';
import '../actors/ghost.dart';
import '../haunted_dorm_game.dart';
import 'collision_block.dart';
import '../objects/door.dart';
import '../objects/bed.dart';
import '../objects/building_slot.dart';

class Level extends World with HasGameReference<HauntedDormGame> {
  final String levelName;
  final Player player;
  late TiledComponent level;

  final List<Bed> allBeds = [];
  final List<Door> allDoors = [];
  final List<AIHunter> aiHunters = [];
  final List<BuildingSlot> allSlots = [];

  Level({required this.levelName, required this.player});

  @override
  FutureOr<void> onLoad() async {
    try {
      level = await TiledComponent.load(
        '$levelName.tmx',
        Vector2.all(32),
        prefix: 'assets/tiles/',
      );
      add(level);

      player.collisionBlocks.clear();
      player.beds.clear();

      _processLayersInOrder();

      if (!player.isMounted) add(player);
    } catch (e, stack) {
      add(player);
      developer.log(
        'Error loading level $levelName',
        error: e,
        stackTrace: stack,
      );
    }
    return super.onLoad();
  }

  void _processLayersInOrder() {
    ObjectGroup? spawnLayer;
    ObjectGroup? slotLayer;

    for (final layer in level.tileMap.map.layers) {
      if (layer is ObjectGroup) {
        if (layer.name == 'Object Layer' || layer.name == 'Object') {
          _processObjectLayer(layer);
        } else if (layer.name == 'Collisions') {
          _processCollisionLayer(layer);
        } else if (layer.name == 'Spawn') {
          spawnLayer = layer;
        } else if (layer.name == 'BuildingSlots') {
          slotLayer = layer;
        }
      }
    }

    if (slotLayer != null) _processBuildingSlots(slotLayer);
    _scanRoomsAndAssociate();
    if (spawnLayer != null) _processSpawnLayer(spawnLayer);
  }

  void _processObjectLayer(ObjectGroup layer) {
    for (final object in layer.objects) {
      final String type = object.type.isNotEmpty
          ? object.type
          : (object.class_.isNotEmpty ? object.class_ : object.name);

      if (type == 'Door') {
        final door = Door(
          position: Vector2(object.x, object.y),
          size: Vector2(object.width, object.height),
        );
        add(door);
        allDoors.add(door);
        player.collisionBlocks.add(door.collisionBlock);
      } else if (type == 'Bed') {
        final bed = Bed(
          position: Vector2(object.x, object.y),
          size: Vector2(object.width, object.height),
          orientation: object.name,
        );
        add(bed);
        player.beds.add(bed);
        allBeds.add(bed);
      }
    }
  }

  void _scanRoomsAndAssociate() {
    for (int i = 0; i < allBeds.length; i++) {
      final bed = allBeds[i];
      bed.roomID = i;
      final queue = Queue<Vector2>();
      final visited = <String>{};
      queue.add(
        Vector2((bed.x / 32).floorToDouble(), (bed.y / 32).floorToDouble()),
      );
      while (queue.isNotEmpty) {
        final current = queue.removeFirst();
        final key = '${current.x},${current.y}';
        if (visited.contains(key)) continue;
        visited.add(key);
        final worldPos = current * 32;
        final tileRect = Rect.fromLTWH(worldPos.x, worldPos.y, 32, 32);
        for (final slot in allSlots) {
          if (slot.toRect().overlaps(tileRect)) {
            slot.roomID = i;
            slot.associatedBed = bed;
          }
        }
        bool hitDoor = false;
        for (final door in allDoors) {
          if (door.toRect().overlaps(tileRect)) {
            door.roomID = i;
            door.associatedBed = bed;
            hitDoor = true;
          }
        }
        if (hitDoor) continue;
        final neighbors = [
          Vector2(current.x + 1, current.y),
          Vector2(current.x - 1, current.y),
          Vector2(current.x, current.y + 1),
          Vector2(current.x, current.y - 1),
        ];
        for (final next in neighbors) {
          final nextWorldPos = next * 32;
          final nextRect = Rect.fromLTWH(
            nextWorldPos.x + 8,
            nextWorldPos.y + 8,
            16,
            16,
          );
          bool isWallOrDoor = false;
          for (final block in player.collisionBlocks) {
            if (block.toRect().overlaps(nextRect)) {
              isWallOrDoor = true;
              break;
            }
          }
          if (!isWallOrDoor && !visited.contains('${next.x},${next.y}')) {
            if ((next - Vector2(bed.x / 32, bed.y / 32)).length < 15) {
              queue.add(next);
            }
          }
        }
      }
    }
  }

  void _processSpawnLayer(ObjectGroup layer) {
    int hunterCount = 0;
    final types = ['nun', 'max', 'jack', 'nun', 'max', 'jack', 'nun'];

    for (final object in layer.objects) {
      final String objType = object.type.isNotEmpty
          ? object.type
          : object.class_;

      if (objType == 'Hunter' ||
          object.name == 'Spawn' ||
          object.name == 'HunterSpawn') {
        if (hunterCount == 0) {
          player.position = Vector2(object.x + 16, object.y + 16);
          hunterCount++;
        } else if (hunterCount <= 7) {
          final ai = AIHunter(characterType: types[hunterCount - 1]);
          ai.position = Vector2(object.x + 16, object.y + 16);
          ai.collisionBlocks = player.collisionBlocks;
          ai.beds = allBeds;

          aiHunters.add(ai);
          add(ai);
          // game.hunters is defined as List<AIHunter> in HauntedDormGame.
          // We can't add Player directly if it's strict, but we can manage them separately.
          game.hunters.add(ai);
          hunterCount++;
        }
      } else if (object.name == 'DreamMonster' || objType == 'MonsterSpawn') {
        final ghost = Ghost(
          position: Vector2(object.x + 16, object.y + 16),
          size: Vector2(32, 48),
        );
        add(ghost);
      }
    }
    _assignAIBeds();
  }

  void _processCollisionLayer(ObjectGroup layer) {
    for (final collision in layer.objects) {
      final block = CollisionBlock(
        position: Vector2(collision.x, collision.y),
        size: Vector2(collision.width, collision.height),
      );
      player.collisionBlocks.add(block);
      add(block);
    }
  }

  void _processBuildingSlots(ObjectGroup layer) {
    for (final slot in layer.objects) {
      final buildingSlot = BuildingSlot(
        position: Vector2(slot.x, slot.y),
        size: Vector2(slot.width, slot.height),
      );
      add(buildingSlot);
      allSlots.add(buildingSlot);
    }
  }

  void _assignAIBeds() {
    final availableBeds = List<Bed>.from(allBeds);
    for (final ai in aiHunters) {
      if (availableBeds.isNotEmpty) {
        final bed = availableBeds.removeLast();
        ai.setTargetBed(bed);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _checkPlayerInAIRoom();
  }

  void _checkPlayerInAIRoom() {
    for (final ai in aiHunters) {
      if (ai.targetBed != null) {
        final distance = (player.position - ai.targetBed!.position).length;
        if (distance < 64) {
          ai.yieldBed();
          _reassignAI(ai);
        }
      }
    }
  }

  void _reassignAI(AIHunter ai) {
    final assignedBeds = aiHunters.map((h) => h.targetBed).toSet();
    for (final bed in allBeds) {
      if (!assignedBeds.contains(bed) && player.currentBed != bed) {
        ai.setTargetBed(bed);
        break;
      }
    }
  }
}

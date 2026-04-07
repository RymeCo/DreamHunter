import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'dart:developer' as developer;
import '../actors/player.dart';
import '../actors/ai_hunter.dart';
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

      _processLayers();

      if (!player.isMounted) add(player);
    } catch (e, stack) {
      add(player);
      developer.log('Error loading level $levelName', error: e, stackTrace: stack);
    }
    return super.onLoad();
  }

  void _processLayers() {
    for (final layer in level.tileMap.map.layers) {
      if (layer is ObjectGroup) {
        if (layer.name == 'Object Layer') {
          _processObjectLayer(layer);
        } else if (layer.name == 'Spawn') {
          _processSpawnLayer(layer);
        } else if (layer.name == 'Collisions') {
          _processCollisionLayer(layer);
        } else if (layer.name == 'BuildingSlots') {
          _processBuildingSlots(layer);
        }
      }
    }
    
    // FIX: Link doors to rooms with a much larger search radius
    _linkDoorsToBeds();
  }

  void _processObjectLayer(ObjectGroup layer) {
    for (final object in layer.objects) {
      final String type = object.type.isNotEmpty ? object.type : (object.class_.isNotEmpty ? object.class_ : object.name);

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

  void _linkDoorsToBeds() {
    // Each door needs to find its bed to know which room it protects
    for (final door in allDoors) {
      Bed? nearest;
      double minDist = double.infinity;
      for (final bed in allBeds) {
        final dist = (door.position - bed.position).length;
        // 400px radius ensures we find the door even in big rooms
        if (dist < minDist && dist < 400) { 
          minDist = dist;
          nearest = bed;
        }
      }
      door.associatedBed = nearest;
    }
  }

  void _processSpawnLayer(ObjectGroup layer) {
    int aiCount = 0;
    final types = ['nun', 'max', 'jack', 'nun', 'max', 'jack', 'nun'];

    for (final object in layer.objects) {
      if (object.class_ == 'Hunter' || object.name == 'Spawn' || object.name == 'HunterSpawn') {
        if (aiCount == 0) {
          player.position = Vector2(object.x + 16, object.y + 24);
          aiCount++;
        } else if (aiCount <= 7) {
          final ai = AIHunter(characterType: types[aiCount - 1]);
          ai.position = Vector2(object.x + 16, object.y + 24);
          aiHunters.add(ai);
          add(ai);
          game.hunters.add(ai);
          aiCount++;
        }
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
      Bed? nearest;
      double minDist = double.infinity;
      for (final bed in allBeds) {
        final dist = (buildingSlot.position - bed.position).length;
        if (dist < minDist) {
          minDist = dist;
          nearest = bed;
        }
      }
      buildingSlot.associatedBed = nearest;
      add(buildingSlot);
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

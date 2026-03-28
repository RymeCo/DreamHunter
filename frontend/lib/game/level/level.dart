import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';
import '../actors/player.dart';
import 'collision_block.dart';
import '../objects/door.dart';
import '../objects/bed.dart';

/// Tiled Object Classes/Names handled:
/// - Spawn: Player starting position
/// - Door: Interactable door with collision
/// - Bed: Passable bed object
/// - Turret: Placeholder for future turret
/// - EnergyMaker: Placeholder for future energy maker
class Level extends World {
  final String levelName;
  final Player player;
  late TiledComponent level;
  List<CollisionBlock> collisions = [];

  Level({required this.levelName, required this.player});

  @override
  FutureOr<void> onLoad() async {
    try {
      level = await TiledComponent.load(
        '$levelName.tmx', 
        Vector2.all(32), // Updated to 32x32 to match your map
        prefix: 'assets/images/',
      );
      add(level);

      // Hide the Object tile layer as we spawn components for them
      final objectTileLayer = level.tileMap.getLayer<TileLayer>('Object');
      if (objectTileLayer != null) {
        objectTileLayer.visible = false;
      }

      // Support both 'Spawnpoint' and 'Spawnpoints'
      var spawnPointLayer = level.tileMap.getLayer<ObjectGroup>('Spawnpoints') ?? 
                           level.tileMap.getLayer<ObjectGroup>('Spawnpoint');
      
      if (spawnPointLayer != null) {
        for (final spawnPoint in spawnPointLayer.objects) {
          // Check both class and name for 'Player'
          if (spawnPoint.class_ == 'Player' || spawnPoint.name == 'Player') {
            player.position = Vector2(spawnPoint.x, spawnPoint.y);
          }
        }
      }

      // Support both 'ObjectLayer' and 'Object' (as seen in screenshot)
      var objectLayer = level.tileMap.getLayer<ObjectGroup>('ObjectLayer') ??
                        level.tileMap.getLayer<ObjectGroup>('Object');

      if (objectLayer != null) {
        for (final object in objectLayer.objects) {
          // Robust type detection
          final String type = object.class_.isNotEmpty ? object.class_ : object.name;
          
          switch (type) {
            case 'Spawn':
            case 'Player':
              player.position = Vector2(object.x + object.width / 2, object.y + object.height);
              break;
            case 'Door':
              final door = Door(
                position: Vector2(object.x, object.y),
                size: Vector2(object.width, object.height),
              );
              add(door);
              collisions.add(door.collisionBlock);
              break;
            case 'Bed':
              final bed = Bed(
                position: Vector2(object.x, object.y),
                size: Vector2(object.width, object.height),
              );
              add(bed);
              player.beds.add(bed);
              break;
          }
        }
      }
      
      if (!player.isMounted) {
        add(player);
      }

      // Support both 'Collisions' and 'Collision' (as seen in screenshot)
      var collisionsLayer = level.tileMap.getLayer<ObjectGroup>('Collisions') ??
                            level.tileMap.getLayer<ObjectGroup>('Collision');

      if (collisionsLayer != null) {
        for (final collision in collisionsLayer.objects) {
          final block = CollisionBlock(
            position: Vector2(collision.x, collision.y),
            size: Vector2(collision.width, collision.height),
          );
          collisions.add(block);
          add(block);
        }
      }
      
      player.collisionBlocks = collisions;
    } catch (e) {
      add(player);
      debugPrint('Error loading level $levelName: $e');
    }

    return super.onLoad();
  }
}

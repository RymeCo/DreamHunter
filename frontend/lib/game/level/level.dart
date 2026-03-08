import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';
import '../actors/player.dart';
import 'collision_block.dart';

class Level extends World {
  final String levelName;
  final Player player;
  late TiledComponent level;
  List<CollisionBlock> collisions = [];

  Level({required this.levelName, required this.player});

  @override
  FutureOr<void> onLoad() async {
    try {
      level = await TiledComponent.load('$levelName.tmx', Vector2.all(16));
      add(level);

      final spawnPointLayer = level.tileMap.getLayer<ObjectGroup>('Spawnpoints');
      if (spawnPointLayer != null) {
        for (final spawnPoint in spawnPointLayer.objects) {
          switch (spawnPoint.class_) {
            case 'Player':
              player.position = Vector2(spawnPoint.x, spawnPoint.y);
              break;
            default:
          }
        }
      }
      
      // Ensure player is added once after trying to find spawnpoint
      if (!player.isMounted) {
        add(player);
      }

      final collisionsLayer = level.tileMap.getLayer<ObjectGroup>('Collisions');
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

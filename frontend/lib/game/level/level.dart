import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'dart:developer' as developer;
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

  Level({required this.levelName, required this.player});

  @override
  FutureOr<void> onLoad() async {
    try {
      developer.log('SCRUM-66: Loading level: $levelName', name: 'Level');
      level = await TiledComponent.load(
        '$levelName.tmx', 
        Vector2.all(32), // Updated to 32x32 to match your map
        prefix: 'assets/images/',
      );
      add(level);

      // Hide the Object tile layer if it exists
      final objectTileLayer = level.tileMap.getLayer<TileLayer>('Object');
      if (objectTileLayer != null) {
        objectTileLayer.visible = false;
      }

      // Clear existing lists to avoid duplicates on reload
      player.collisionBlocks.clear();
      player.beds.clear();

      // Support both 'Spawnpoint' and 'Spawnpoints'
      var spawnPointLayer = level.tileMap.getLayer<ObjectGroup>('Spawnpoints') ?? 
                           level.tileMap.getLayer<ObjectGroup>('Spawnpoint');
      
      if (spawnPointLayer != null) {
        for (final spawnPoint in spawnPointLayer.objects) {
          if (spawnPoint.class_ == 'Player' || spawnPoint.name == 'Player' || spawnPoint.class_ == 'Spawn') {
            player.position = Vector2(spawnPoint.x, spawnPoint.y);
            developer.log('SCRUM-66: Player spawned via Spawnpoint layer at: ${player.position}', name: 'Level');
          }
        }
      }

      // Support both 'ObjectLayer' and 'Object'
      var objectLayer = level.tileMap.getLayer<ObjectGroup>('ObjectLayer') ??
                        level.tileMap.getLayer<ObjectGroup>('Object');

      if (objectLayer != null) {
        developer.log('SCRUM-66: Processing ObjectLayer with ${objectLayer.objects.length} objects', name: 'Level');
        for (final object in objectLayer.objects) {
          final String type = object.class_.isNotEmpty ? object.class_ : object.name;
          
          switch (type) {
            case 'Spawn':
            case 'Player':
              player.position = Vector2(object.x, object.y);
              developer.log('SCRUM-66: Player spawned via ObjectLayer at: ${player.position}', name: 'Level');
              break;
            case 'Door':
              final door = Door(
                position: Vector2(object.x, object.y),
                size: Vector2(object.width, object.height),
              );
              add(door);
              player.collisionBlocks.add(door.collisionBlock);
              break;
            case 'Bed':
              final bed = Bed(
                position: Vector2(object.x, object.y),
                size: Vector2(object.width, object.height),
              );
              add(bed);
              player.beds.add(bed);
              developer.log('SCRUM-66: Bed added at: ${bed.position}', name: 'Level');
              break;
          }
        }
      }
      
      if (!player.isMounted) {
        add(player);
      }

      // Support both 'Collisions' and 'Collision'
      var collisionsLayer = level.tileMap.getLayer<ObjectGroup>('Collisions') ??
                            level.tileMap.getLayer<ObjectGroup>('Collision');

      if (collisionsLayer != null) {
        developer.log('SCRUM-66: Processing CollisionLayer with ${collisionsLayer.objects.length} objects', name: 'Level');
        for (final collision in collisionsLayer.objects) {
          final block = CollisionBlock(
            position: Vector2(collision.x, collision.y),
            size: Vector2(collision.width, collision.height),
          );
          player.collisionBlocks.add(block);
          add(block);
        }
      }
      developer.log('SCRUM-66: Level load complete. Collisions: ${player.collisionBlocks.length}, Beds: ${player.beds.length}', name: 'Level');
    } catch (e, stack) {
      add(player);
      developer.log('SCRUM-66: Error loading level $levelName', name: 'Level', error: e, stackTrace: stack);
    }

    return super.onLoad();
  }
}

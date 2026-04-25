import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/player_entity.dart';
import 'package:dreamhunter/game/entities/map_obstacle.dart';
import 'package:dreamhunter/game/entities/bed_entity.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/ui/dynamic_joystick.dart';

class DreamHunterGame extends FlameGame with DragCallbacks, HasCollisionDetection {
  final VoidCallback? onMatchEnded;
  final ValueNotifier<int> graceTimer = ValueNotifier(10);
  final ValueNotifier<int> matchTimer = ValueNotifier(15 * 60);

  late final PlayerEntity player;
  late final DynamicJoystick joystick;
  
  // Track the current drag position manually for maximum fluidity and compatibility
  Vector2 _dragPosition = Vector2.zero();

  DreamHunterGame({this.onMatchEnded});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 1. Load Map
    final map = await TiledComponent.load('dorm-01.tmx', Vector2.all(32));
    world.add(map);

    // 2. Parse Collisions from Tiled
    final collisionLayer = map.tileMap.getLayer<ObjectGroup>('Collisions');
    if (collisionLayer != null) {
      for (final obj in collisionLayer.objects) {
        world.add(MapObstacle(
          position: Vector2(obj.x, obj.y),
          size: Vector2(obj.width, obj.height),
        ));
      }
    }

    // 3. Parse Objects (Beds, etc.) from Tiled
    final objectLayer = map.tileMap.getLayer<ObjectGroup>('Object Layer');
    if (objectLayer != null) {
      for (final obj in objectLayer.objects) {
        if (obj.type == 'Bed') {
          world.add(BedEntity(
            position: Vector2(obj.x, obj.y),
          ));
        }
      }
    }

    // 4. Initialize Joystick
    joystick = DynamicJoystick();
    camera.viewport.add(joystick);

    // 4. Spawn Player
    player = PlayerEntity(joystick: joystick);
    player.position = Vector2(1280 / 2, 1280 / 2); // Center of the dorm map
    world.add(player);

    // 5. Configure Camera
    camera.viewfinder.visibleGameSize = Vector2(7 * 32, 0);
    camera.viewfinder.anchor = Anchor.center;
    camera.follow(player);

    // 6. Combined Timer Logic (Flame Native)
    add(
      TimerComponent(
        period: 1,
        repeat: true,
        onTick: () {
          // Grace Period Countdown
          if (graceTimer.value >= 0) {
            graceTimer.value--;
          }
          
          // 15-Minute Match Countdown
          if (matchTimer.value > 0) {
            matchTimer.value--;
            if (matchTimer.value == 0) {
              onMatchEnded?.call();
            }
          }
        },
      ),
    );

    debugPrint('DreamHunterGame: Map Loaded, Player Spawned, and Timers started.');
  }

  /// Checks if a given hitbox (at a potential position) would collide with any walls.
  bool isPositionBlocked(Rect hitbox) {
    // Check Tiled Map Obstacles
    final obstacles = world.children.whereType<MapObstacle>();
    for (final obstacle in obstacles) {
      if (obstacle.toRect().overlaps(hitbox)) {
        return true;
      }
    }

    // Check Buildings (Beds, etc.)
    final buildings = world.children.whereType<BaseEntity>().where((e) => e.hasCategory('building'));
    for (final building in buildings) {
      if (building.toRect().overlaps(hitbox)) {
        return true;
      }
    }

    return false;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!joystick.isMounted) return;
    _dragPosition = event.localPosition;
    joystick.startDrag(_dragPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!joystick.isMounted) {
      // Free Look Mode: Move the camera viewfinder in the opposite direction of the drag
      camera.viewfinder.position.sub(event.localDelta);
      return;
    }
    _dragPosition += event.localDelta;
    joystick.updateDrag(_dragPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!joystick.isMounted) return;
    joystick.endDrag();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (!joystick.isMounted) return;
    joystick.endDrag();
  }

  @override
  void onRemove() {
    graceTimer.dispose();
    matchTimer.dispose();
    super.onRemove();
  }
}

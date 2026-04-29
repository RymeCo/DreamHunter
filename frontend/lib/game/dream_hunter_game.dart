import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/player_entity.dart';
import 'package:dreamhunter/game/entities/map_obstacle.dart';
import 'package:dreamhunter/game/entities/bed_entity.dart';
import 'package:dreamhunter/game/entities/door_entity.dart';
import 'package:dreamhunter/game/entities/building_slot_entity.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/entities/hunter_ai_entity.dart';
import 'package:dreamhunter/game/ui/dynamic_joystick.dart';
import 'package:dreamhunter/services/game/match_manager.dart';

class DreamHunterGame extends FlameGame
    with DragCallbacks, HasCollisionDetection {
  final VoidCallback? onMatchEnded;
  final ValueNotifier<int> graceTimer = ValueNotifier(30);
  final ValueNotifier<int> matchTimer = ValueNotifier(15 * 60);

  late final PlayerEntity player;
  late final DynamicJoystick joystick;

  /// Active AI hunters in the world
  final List<HunterAIEntity> aiHunters = [];

  /// Active monsters in the world for turret targeting
  final Set<BaseEntity> monsters = {};

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
        world.add(
          MapObstacle(
            position: Vector2(obj.x, obj.y),
            size: Vector2(obj.width, obj.height),
          ),
        );
      }
    }

    // 3. Parse Objects (Beds, etc.) from Tiled
    final objectLayer = map.tileMap.getLayer<ObjectGroup>('Object Layer');
    if (objectLayer != null) {
      for (final obj in objectLayer.objects) {
        final pos = Vector2(obj.x, obj.y);
        if (obj.type == 'Bed') {
          world.add(BedEntity(position: pos, roomID: obj.name));
        } else if (obj.type == 'Door') {
          world.add(DoorEntity(position: pos, roomID: obj.name));
        }
      }
    }

    // New: Parse Building Slots from its dedicated layer
    final slotsLayer = map.tileMap.getLayer<ObjectGroup>('BuildingSlots');
    if (slotsLayer != null) {
      for (final obj in slotsLayer.objects) {
        if (obj.type == 'BuildingSlot') {
          world.add(
            BuildingSlotEntity(
              position: Vector2(obj.x, obj.y),
              roomID: obj.name,
            ),
          );
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

    // 4.1 Spawn AI Hunters from Lobby
    aiHunters.clear();
    final aiSkins = MatchManager.instance.aiSkins;
    for (int i = 0; i < aiSkins.length; i++) {
      // Clustered spawn offsets around the player (within 32-48px radius)
      final angle = (i * (2 * 3.14159 / 5)); // Spread around a circle
      final offset = Vector2(
        32 * math.cos(angle),
        32 * math.sin(angle),
      );
      final ai = HunterAIEntity(
        skinPath: aiSkins[i],
        position: player.position + offset,
      );
      aiHunters.add(ai);
      world.add(ai);
    }

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

    // 7. Link Beds to Doors (Room Assignment)
    final beds = world.children.whereType<BedEntity>();
    final doors = world.children.whereType<DoorEntity>();
    final slots = world.children.whereType<BuildingSlotEntity>();

    // Cleanup: Remove slots that overlap with Beds or Doors (Distance < 24)
    for (final slot in slots.toList()) {
      bool isOverlapping = false;

      for (final bed in beds) {
        if (slot.position.distanceTo(bed.position) < 24) {
          isOverlapping = true;
          break;
        }
      }

      if (!isOverlapping) {
        for (final door in doors) {
          if (slot.position.distanceTo(door.position) < 24) {
            isOverlapping = true;
            break;
          }
        }
      }

      if (isOverlapping) {
        slot.removeFromParent();
      }
    }

    for (final bed in beds) {
      // 1. Try to link by explicit Room ID (from Tiled 'name' property)
      if (bed.roomID.isNotEmpty) {
        for (final door in doors) {
          if (door.roomID == bed.roomID) {
            bed.roomDoor = door;
            break;
          }
        }
      }

      // 2. Fallback to proximity if no ID match was found
      if (bed.roomDoor == null) {
        DoorEntity? nearest;
        double minDistance =
            250; // Threshold to ensure we don't link to far away doors
        final bedCenter = bed.position + (bed.size / 2);

        for (final door in doors) {
          final doorCenter = door.position + (door.size / 2);
          final dist = bedCenter.distanceTo(doorCenter);
          if (dist < minDistance) {
            minDistance = dist;
            nearest = door;
          }
        }
        bed.roomDoor = nearest;
      }
    }
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
    final buildings = world.children.whereType<BaseEntity>().where(
      (e) => e.hasCategory('building'),
    );
    for (final building in buildings) {
      if (building.toRect().overlaps(hitbox)) {
        return true;
      }
    }

    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Drive the frame-independent match logic (coins, energy, ticks)
    MatchManager.instance.update(dt);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragPosition = event.localPosition;
    if (joystick.isMounted) {
      joystick.startDrag(_dragPosition);
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!joystick.isMounted) {
      // Free Look Mode: Pan the camera viewfinder by dividing by zoom
      // We use explicit assignment here to ensure the camera dirty flag is set.
      final panDelta = Vector2(
        -event.localDelta.x / camera.viewfinder.zoom,
        -event.localDelta.y / camera.viewfinder.zoom,
      );
      camera.viewfinder.position = camera.viewfinder.position + panDelta;
      return;
    }
    _dragPosition += event.localDelta;
    joystick.updateDrag(_dragPosition);
  }

  /// Instantly centers the camera on the player.
  void centerCameraOnPlayer() {
    centerCameraOnEntity(player);
  }

  /// Instantly centers the camera on a specific entity.
  void centerCameraOnEntity(PositionComponent entity) {
    camera.viewfinder.position = entity.position;
  }

  /// Centers camera on a hunter by index (0 for player, 1-5 for AI)
  void centerCameraOnHunter(int index) {
    if (index == 0) {
      centerCameraOnPlayer();
    } else if (index - 1 < aiHunters.length) {
      centerCameraOnEntity(aiHunters[index - 1]);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (joystick.isMounted) {
      joystick.endDrag();
    }
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (joystick.isMounted) {
      joystick.endDrag();
    }
  }

  @override
  void onRemove() {
    graceTimer.dispose();
    matchTimer.dispose();
    super.onRemove();
  }
}

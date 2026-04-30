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

  /// Cached lists for high-performance collision checks (Updated in onLoad/onRemove)
  final List<MapObstacle> _obstacles = [];
  final List<BaseEntity> _buildings = [];
  final List<BaseEntity> buildingSlots = [];

  /// Global grid for AI pathfinding
  late final List<List<bool>> wallGrid;
  static const int gridW = 40; // 1280 / 32
  static const int gridH = 40;

  /// Pre-calculated distance maps for every bed (Key: roomID)
  final Map<String, List<List<int>>> bedFlowFields = {};

  /// Global TextPaint for building slots to prevent GC lag.
  /// Re-instantiated once per frame with new opacity.
  late TextPaint buildingSlotPaint;
  double _pulseTimer = 0;

  // Track the current drag position manually for maximum fluidity and compatibility
  Vector2 _dragPosition = Vector2.zero();

  DreamHunterGame({this.onMatchEnded});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Initialize global paint
    buildingSlotPaint = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );

    // 1. Load Map
    final map = await TiledComponent.load('dorm-01.tmx', Vector2.all(32));
    world.add(map);

    // 2. Parse Collisions from Tiled
    final collisionLayer = map.tileMap.getLayer<ObjectGroup>('Collisions');
    if (collisionLayer != null) {
      for (final obj in collisionLayer.objects) {
        final obstacle = MapObstacle(
          position: Vector2(obj.x, obj.y),
          size: Vector2(obj.width, obj.height),
        );
        _obstacles.add(obstacle);
        world.add(obstacle);
      }
    }

    // 3. Parse Objects (Beds, etc.) from Tiled
    final objectLayer = map.tileMap.getLayer<ObjectGroup>('Object Layer');
    final List<BedEntity> parsedBeds = [];
    final List<DoorEntity> parsedDoors = [];
    if (objectLayer != null) {
      for (final obj in objectLayer.objects) {
        final pos = Vector2(obj.x, obj.y);
        final roomID = obj.name.trim();
        if (obj.type == 'Bed') {
          final bed = BedEntity(position: pos, roomID: roomID);
          parsedBeds.add(bed);
          world.add(bed);
        } else if (obj.type == 'Door') {
          final door = DoorEntity(position: pos, roomID: roomID);
          parsedDoors.add(door);
          world.add(door);
        }
      }
    }

    // New: Parse Building Slots from its dedicated layer
    final List<BuildingSlotEntity> parsedSlots = [];
    final slotsLayer = map.tileMap.getLayer<ObjectGroup>('BuildingSlots');
    if (slotsLayer != null) {
      for (final obj in slotsLayer.objects) {
        if (obj.type == 'BuildingSlot') {
          final slot = BuildingSlotEntity(
            position: Vector2(obj.x, obj.y),
            roomID: obj.name.trim(),
          );
          parsedSlots.add(slot);
          world.add(slot);
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

    aiHunters.clear();

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

    // 7. Link ALL Beds to their Doors (Resilient Strategy)
    for (final bed in parsedBeds) {
      final bedID = bed.roomID.toLowerCase();

      // Attempt 1: Exact roomID match (Standardized to lowercase)
      if (bedID.isNotEmpty) {
        for (final door in parsedDoors) {
          if (door.roomID.toLowerCase() == bedID) {
            bed.roomDoor = door;
            break;
          }
        }
      }

      // Attempt 2: Proximity Fallback (If no roomID match or roomID is empty)
      if (bed.roomDoor == null) {
        DoorEntity? nearestDoor;
        double minDist = 300; // Max proximity range (300px is roughly 9 tiles)

        for (final door in parsedDoors) {
          final dist = bed.position.distanceTo(door.position);
          if (dist < minDist) {
            minDist = dist;
            nearestDoor = door;
          }
        }
        bed.roomDoor = nearestDoor;
      }
    }

    // 8. Furniture Cleanup (Remove slots that overlap with Beds or Doors)
    for (final slot in parsedSlots) {
      bool overlaps = false;

      // Check Bed Overlap
      for (final bed in parsedBeds) {
        if (slot.position.distanceTo(bed.position) < 16) {
          overlaps = true;
          break;
        }
      }
      if (overlaps) {
        slot.removeFromParent();
        continue;
      }

      // Check Door Overlap
      for (final door in parsedDoors) {
        if (slot.position.distanceTo(door.position) < 16) {
          overlaps = true;
          break;
        }
      }
      if (overlaps) {
        slot.removeFromParent();
      }
    }
    // MAP ANALYSIS: Mark every 32x32 square as "Ground" or "Wall"
    wallGrid = List.generate(gridW, (_) => List.generate(gridH, (_) => false));

    for (final obstacle in _obstacles) {
      final rect = obstacle.toRect();
      // Calculate tile boundaries that this obstacle touches
      final startX = (rect.left / 32.0).floor().clamp(0, gridW - 1);
      final endX = (rect.right / 32.0).floor().clamp(0, gridW - 1);
      final startY = (rect.top / 32.0).floor().clamp(0, gridH - 1);
      final endY = (rect.bottom / 32.0).floor().clamp(0, gridH - 1);

      for (int x = startX; x <= endX; x++) {
        for (int y = startY; y <= endY; y++) {
          final tileRect = Rect.fromLTWH(x * 32.0, y * 32.0, 32.0, 32.0);
          if (rect.overlaps(tileRect)) {
            wallGrid[x][y] = true;
          }
        }
      }
    }

    final aiSkins = MatchManager.instance.aiSkins;
    parsedBeds.shuffle(math.Random());

    // PRE-CALCULATE FLOW FIELDS: Every bed gets a gravity map
    for (final bed in parsedBeds) {
      bedFlowFields[bed.roomID] = _generateFlowField(bed);
    }

    // THE START: All AI hunters spawn at the player's tile center.
    final spawnX = (player.position.x / 32).floor().clamp(0, gridW - 1);
    final spawnY = (player.position.y / 32).floor().clamp(0, gridH - 1);
    final spawnTile = math.Point(spawnX, spawnY);

    for (int i = 0; i < aiSkins.length; i++) {
      if (parsedBeds.isEmpty) break;
      final assignedBed = parsedBeds.removeAt(0);

      // SPAWN: Add the hunter to the world.
      final ai = HunterAIEntity(
        skinPath: aiSkins[i],
        targetBed: assignedBed,
        position: Vector2(
          spawnTile.x * 32.0 + 16.0 + (i * 2),
          spawnTile.y * 32.0 + 16.0 + (i * 2),
        ),
      );

      assignedBed.reservedBy = ai;
      aiHunters.add(ai);
      world.add(ai);
    }
  }

  /// Checks if a given hitbox (at a potential position) would collide with any walls.
  /// Note: Hunters (Player and AI) do not block each other's movement; they pass through.
  bool isPositionBlocked(Rect hitbox, {List<BaseEntity>? ignoredEntities}) {
    // Check Tiled Map Obstacles (Stone walls)
    for (final obstacle in _obstacles) {
      if (obstacle.toRect().overlaps(hitbox)) {
        return true;
      }
    }

    // Check Buildings (Doors, etc.)
    for (final building in _buildings) {
      if (ignoredEntities != null && ignoredEntities.contains(building)) {
        continue;
      }
      if (building.toRect().overlaps(hitbox)) {
        return true;
      }
    }
    return false;
  }

  /// Registers a building for collision tracking.
  void registerBuilding(BaseEntity building) {
    if (!_buildings.contains(building)) {
      _buildings.add(building);
    }
  }

  /// Unregisters a building from collision tracking.
  void unregisterBuilding(BaseEntity building) {
    _buildings.remove(building);
  }

  /// Registers a building slot for AI lookup.
  void registerBuildingSlot(BaseEntity slot) {
    if (!buildingSlots.contains(slot)) {
      buildingSlots.add(slot);
    }
  }

  /// Unregisters a building slot.
  void unregisterBuildingSlot(BaseEntity slot) {
    buildingSlots.remove(slot);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update global building slot pulse
    _pulseTimer += dt;
    final double opacity =
        ((math.sin(_pulseTimer * (math.pi / 1.5)) + 1) / 4); // Range [0.0, 0.5]
    buildingSlotPaint = TextPaint(
      style: TextStyle(
        color: Colors.white.withValues(alpha: opacity),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );

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

  /// Generates a distance map (Flow Field) for a specific bed.
  /// Every tile stores its distance to the bed. 9999 = Unreachable.
  List<List<int>> _generateFlowField(BedEntity bed) {
    final field = List.generate(
      gridW,
      (_) => List.generate(gridH, (_) => 9999),
    );

    final targetX = (bed.position.x / 32).floor().clamp(0, gridW - 1);
    final targetY = (bed.position.y / 32).floor().clamp(0, gridH - 1);
    final targetTile = math.Point(targetX, targetY);

    final List<math.Point<int>> queue = [targetTile];
    field[targetX][targetY] = 0;
    int head = 0;

    while (head < queue.length) {
      final current = queue[head++];
      final currentDist = field[current.x][current.y];

      for (final dir in [
        const math.Point(1, 0),
        const math.Point(-1, 0),
        const math.Point(0, 1),
        const math.Point(0, -1),
      ]) {
        final next = math.Point(current.x + dir.x, current.y + dir.y);
        if (next.x >= 0 && next.x < gridW && next.y >= 0 && next.y < gridH) {
          bool isBlocked = wallGrid[next.x][next.y];

          // Treat the room's own door as walkable so the AI can enter
          if (bed.roomDoor != null) {
            final dx = (bed.roomDoor!.position.x / 32).floor();
            final dy = (bed.roomDoor!.position.y / 32).floor();
            if (next.x == dx && next.y == dy) isBlocked = false;
          }

          if (!isBlocked && field[next.x][next.y] == 9999) {
            field[next.x][next.y] = currentDist + 1;
            queue.add(next);
          }
        }
      }
    }
    return field;
  }
}

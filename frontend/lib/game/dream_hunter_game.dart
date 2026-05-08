import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flame/flame.dart';
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
import 'package:dreamhunter/game/entities/monster_entity.dart';
import 'package:dreamhunter/game/components/room_fog_layer.dart';
import 'package:dreamhunter/game/ui/dynamic_joystick.dart';
import 'package:dreamhunter/game/ui/repair_button.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/services/economy/shop_manager.dart';
import 'package:dreamhunter/data/item_registry.dart';

import 'package:dreamhunter/services/game/performance_manager.dart';

import 'package:dreamhunter/game/components/floating_feedback.dart';

class DreamHunterGame extends FlameGame
    with DragCallbacks, HasCollisionDetection {
  final VoidCallback? onMatchEnded;
  final ValueNotifier<int> graceTimer = ValueNotifier(30);
  final ValueNotifier<int> stopwatch = ValueNotifier(0);

  late final PlayerEntity player;
  late final DynamicJoystick joystick;

  /// Active AI hunters in the world
  final List<HunterAIEntity> aiHunters = [];

  /// Active monsters in the world for turret targeting
  final Set<BaseEntity> monsters = {};

  /// Cached lists for high-performance collision checks (Updated in onLoad/onRemove)
  final List<MapObstacle> _obstacles = [];
  final List<BaseEntity> _buildings = [];
  Iterable<BaseEntity> get buildings => _buildings;
  final List<BaseEntity> buildingSlots = [];
  final List<BaseEntity> turrets = []; // For O(1) stun/targeting
  final Map<String, BedEntity> roomBeds = {}; // For O(1) occupancy checks
  final Map<math.Point<int>, DoorEntity> doorMap = {}; // For O(1) LoS checks
  final Map<String, RoomFogLayer> roomFog = {}; // For O(1) room reveals

  /// Global grid for AI pathfinding
  late final List<List<bool>> wallGrid;
  static const int gridW = 40; // 1280 / 32
  static const int gridH = 40;

  /// Cache for flow fields (Dijkstra maps) to avoid redundant per-frame calculations.
  /// LRU implementation: We track the order of access to cap the cache size.
  final Map<String, List<List<int>>> _flowFieldCache = {};
  final List<String> _flowFieldLRU = [];
  static const int _maxFlowFieldCache = 10;

  /// Map of tile coordinates to room IDs for fast lookup (Fog of War)
  final Map<math.Point<int>, String> tileRoomMap = {};

  /// Monster Spawn Points (from Tiled)
  final List<Vector2> monsterSpawnPoints = [];

  /// Current opacity for building slot indicators (0.0 to 0.5)
  double slotOpacity = 0.0;
  double _pulseTimer = 0;

  // Track the current drag position manually for maximum fluidity and compatibility
  Vector2 _dragPosition = Vector2.zero();

  double _evictionMessageCooldown = 0;

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
      final obstacles = collisionLayer.objects.map((obj) {
        return MapObstacle(
          position: Vector2(obj.x, obj.y),
          size: Vector2(obj.width, obj.height),
        );
      }).toList();
      _obstacles.addAll(obstacles);
      world.addAll(obstacles);
    }

    // MAP ANALYSIS: Mark every 32x32 square as "Ground" or "Wall"
    wallGrid = List.generate(gridW, (_) => List.generate(gridH, (_) => false));

    for (final obstacle in _obstacles) {
      final rect = obstacle.toRect();
      final startX = (rect.left / 32.0).floor().clamp(0, gridW - 1);
      final endX = ((rect.right - 0.1) / 32.0).floor().clamp(0, gridW - 1);
      final startY = (rect.top / 32.0).floor().clamp(0, gridH - 1);
      final endY = ((rect.bottom - 0.1) / 32.0).floor().clamp(0, gridH - 1);

      for (int x = startX; x <= endX; x++) {
        for (int y = startY; y <= endY; y++) {
          wallGrid[x][y] = true;
        }
      }
    }

    // 3. Parse Objects (Beds, etc.) from Tiled
    var objectLayer = map.tileMap.getLayer<ObjectGroup>('Object Layer');
    // Fallback if named slightly differently
    objectLayer ??= map.tileMap.getLayer<ObjectGroup>('Objects');
    objectLayer ??= map.tileMap.getLayer<ObjectGroup>('objects');

    final List<BedEntity> parsedBeds = [];
    final List<DoorEntity> parsedDoors = [];
    if (objectLayer != null) {
      for (final obj in objectLayer.objects) {
        final pos = Vector2(obj.x, obj.y);
        final roomID = obj.name.trim();
        final type = obj.type.toLowerCase();

        if (type == 'bed') {
          final bed = BedEntity(position: pos, roomID: roomID);
          parsedBeds.add(bed);
          if (roomID.isNotEmpty) roomBeds[roomID] = bed;
        } else if (type == 'door') {
          final door = DoorEntity(position: pos, roomID: roomID);
          parsedDoors.add(door);

          // Map to grid for O(1) LoS
          final tx = (pos.x / 32.0).floor();
          final ty = (pos.y / 32.0).floor();
          doorMap[math.Point(tx, ty)] = door;
        } else if (obj.name.toLowerCase() == 'dreammonster' ||
            type == 'dreammonster') {
          final centerPos = pos + (Vector2(obj.width, obj.height) / 2);
          // NUDGE: Ensure spawn points aren't inside boundary walls
          if (centerPos.x < 64) centerPos.x = 64;
          if (centerPos.x > 1216) centerPos.x = 1216;
          if (centerPos.y < 64) centerPos.y = 64;
          if (centerPos.y > 1216) centerPos.y = 1216;
          monsterSpawnPoints.add(centerPos);
        }
      }
      world.addAll(parsedBeds);
      world.addAll(parsedDoors);
    }

    // New: Parse Building Slots from its dedicated layer
    final List<BuildingSlotEntity> parsedSlots = [];
    var slotsLayer = map.tileMap.getLayer<ObjectGroup>('BuildingSlots');
    slotsLayer ??= map.tileMap.getLayer<ObjectGroup>('building_slots');
    slotsLayer ??= map.tileMap.getLayer<ObjectGroup>('Building Slots');

    if (slotsLayer != null) {
      for (final obj in slotsLayer.objects) {
        if (obj.type == 'BuildingSlot') {
          String roomID = obj.name.trim();
          if (roomID == 'BuildingSlot') roomID = ''; // Clear generic name

          final slot = BuildingSlotEntity(
            position: Vector2(obj.x, obj.y),
            roomID: roomID,
          );
          parsedSlots.add(slot);
        }
      }
      world.addAll(parsedSlots);
    }

    // New: Also check dedicated Spawn layer for monsters
    var spawnLayer = map.tileMap.getLayer<ObjectGroup>('Spawn');
    spawnLayer ??= map.tileMap.getLayer<ObjectGroup>('spawn');
    if (spawnLayer != null) {
      for (final obj in spawnLayer.objects) {
        if (obj.name == 'DreamMonster' || obj.type == 'DreamMonster') {
          final centerPos =
              Vector2(obj.x, obj.y) + (Vector2(obj.width, obj.height) / 2);
          // NUDGE: Ensure spawn points aren't inside boundary walls
          if (centerPos.x < 64) centerPos.x = 64;
          if (centerPos.x > 1216) centerPos.x = 1216;
          if (centerPos.y < 64) centerPos.y = 64;
          if (centerPos.y > 1216) centerPos.y = 1216;
          monsterSpawnPoints.add(centerPos);
        }
      }
    }

    // 4. GRID-BASED FOG: Flood-fill from each bed to find all tiles in its room
    // This ensures full coverage for non-rectangular rooms.
    final doorTilesForFog = parsedDoors
        .map(
          (d) => math.Point(
            (d.position.x / 32).floor(),
            (d.position.y / 32).floor(),
          ),
        )
        .toSet();

    final Set<math.Point<int>> allRoomTiles = {};

    for (final roomID in roomBeds.keys) {
      final bed = roomBeds[roomID]!;
      final startX = (bed.position.x / 32).floor();
      final startY = (bed.position.y / 32).floor();

      final roomTiles = _floodFillRoom(
        startX,
        startY,
        doorTiles: doorTilesForFog,
      );
      allRoomTiles.addAll(roomTiles);

      // OPTIMIZATION: Register tiles for fast room lookup
      for (final tile in roomTiles) {
        tileRoomMap[tile] = roomID;
      }

      final fogLayer = RoomFogLayer(roomID: roomID, tiles: roomTiles);

      world.add(fogLayer);
      roomFog[roomID] = fogLayer;
    }

    // 5. Initialize Joystick
    joystick = DynamicJoystick();
    camera.viewport.add(joystick);

    camera.viewport.add(RepairButton());

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
    _spawnMonster(); // Spawn at start
    add(
      TimerComponent(
        period: 1,
        repeat: true,
        onTick: () {
          // Grace Period Countdown
          if (graceTimer.value >= 0) {
            graceTimer.value--;
          }

          // Stopwatch Incremental Timer
          stopwatch.value++;
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

    final aiSkins = MatchManager.instance.aiSkins;

    // ASSET OPTIMIZATION: Pre-load all skins (Player + AI) in parallel before spawning
    final List<Future> skinLoads = [];

    // 1. Player skin
    final characterId = ShopManager.instance.selectedCharacterId;
    final item = ItemRegistry.get(characterId);
    final playerSkin =
        item?.image.replaceFirst('assets/images/', '') ??
        'game/characters/max_front-32x48.png';
    skinLoads.add(images.load(playerSkin));

    // 2. AI skins
    for (final skin in aiSkins) {
      skinLoads.add(images.load(skin.replaceFirst('assets/images/', '')));
    }
    await Future.wait(skinLoads);

    parsedBeds.shuffle(math.Random());

    // STARTUP OPTIMIZATION: Removed pre-calculation of all flow fields.
    // They are now generated lazily when an AI needs them.

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
          spawnTile.x * 32.0 + 16.0 + (i * 8),
          spawnTile.y * 32.0 + 16.0 + (i * 8),
        ),
      );
      ai.hunterIndex = i + 1;

      assignedBed.reservedBy = ai;
      aiHunters.add(ai);
      world.add(ai);
    }
  }

  /// Checks if there is a clear line of sight between two positions (no wall tiles).
  /// [ignoredRoomID] allows turrets to see through doors in their own room.
  /// [shaveCorners] allows the ray to slightly clip wall corners for better turret reliability.
  bool hasLineOfSight(
    Vector2 start,
    Vector2 end, {
    String? ignoredRoomID,
    bool shaveCorners = true,
  }) {
    final startTileX = (start.x / 32.0).floor();
    final startTileY = (start.y / 32.0).floor();
    final endTileX = (end.x / 32.0).floor();
    final endTileY = (end.y / 32.0).floor();

    if (startTileX == endTileX && startTileY == endTileY) return true;

    // Simple ray-stepping logic
    final diff = end - start;
    final distance = diff.length;
    final steps = (distance / 8.0).ceil(); // Step every quarter-tile (8px)
    final stepVec = diff / steps.toDouble();

    // Tighter tolerance for corner shaving:
    // We check points slightly indented from the wall edges.
    const double tolerance = 4.0;

    for (int i = 1; i < steps; i++) {
      final point = start + stepVec * i.toDouble();

      // OPTIMIZATION: If we are shaving corners, check if the point is
      // very close to a tile boundary. If so, it's likely a "false positive" clip.
      if (shaveCorners) {
        final relX = point.x % 32.0;
        final relY = point.y % 32.0;
        if ((relX < tolerance || relX > 32.0 - tolerance) &&
            (relY < tolerance || relY > 32.0 - tolerance)) {
          continue; // Skip boundary checks that often hit corners
        }
      }

      final px = (point.x / 32.0).floor().clamp(0, gridW - 1);
      final py = (point.y / 32.0).floor().clamp(0, gridH - 1);

      // 1. Check Static Walls
      if (wallGrid[px][py]) {
        if (px == startTileX && py == startTileY) continue;
        if (px == endTileX && py == endTileY) continue;
        return false;
      }

      // 2. PERFORMANCE OPTIMIZED: Check for Closed Doors using doorMap
      final door = doorMap[math.Point(px, py)];
      if (door != null && !door.isOpen && !door.isDestroyed) {
        // IGNORE DOOR if it belongs to the turret's room
        if (ignoredRoomID != null && door.roomID == ignoredRoomID) {
          continue;
        }

        // Allow if it's the target tile
        if (px == endTileX && py == endTileY) continue;
        return false;
      }
    }

    return true;
  }

  /// Checks if a given hitbox (at a potential position) would collide with any walls.
  /// Note: Hunters (Player and AI) do not block each other's movement; they pass through.
  bool isPositionBlocked(
    Rect hitbox, {
    List<BaseEntity>? ignoredEntities,
    Vector2? targetPos,
  }) {
    // 1. Check Buildings (Doors, etc.) - Full Rect Check (Dynamic)
    for (final building in _buildings) {
      if (ignoredEntities != null && ignoredEntities.contains(building)) {
        continue;
      }

      // DO NOT block if the building is destroyed
      if (building.isDestroyed) continue;

      // DO NOT block if it's an open door
      if (building is DoorEntity && building.isOpen) continue;

      final bRect = building.toRect();
      if (hitbox.overlaps(bRect)) {
        return true;
      }
    }

    // Check wallGrid (Static Walls) - O(1) for high-performance collision detection
    // Check all tiles overlapped by the hitbox for 100% collision integrity
    final startX = (hitbox.left / 32.0).floor().clamp(0, gridW - 1);
    final endX = (hitbox.right / 32.0).floor().clamp(0, gridW - 1);
    final startY = (hitbox.top / 32.0).floor().clamp(0, gridH - 1);
    final endY = (hitbox.bottom / 32.0).floor().clamp(0, gridH - 1);

    for (int tx = startX; tx <= endX; tx++) {
      for (int ty = startY; ty <= endY; ty++) {
        if (wallGrid[tx][ty]) {
          // TARGET OVERRIDE: If the monster is trying to reach a BUILDING placed ON a wall,
          // we must allow it to enter that specific wall tile to perform the attack.
          // This does NOT apply to hunters; monsters must stay in halls while chasing them.
          if (targetPos != null &&
              ignoredEntities != null &&
              ignoredEntities.any((e) => e is DoorEntity || e is BedEntity)) {
            final targetTileX = (targetPos.x / 32.0).floor().clamp(
              0,
              gridW - 1,
            );
            final targetTileY = (targetPos.y / 32.0).floor().clamp(
              0,
              gridH - 1,
            );
            if (tx == targetTileX && ty == targetTileY) {
              continue; // Allow overlapping the target tile
            }
          }
          return true;
        }
      }
    }

    return false;
  }

  /// Returns the building entity that is currently blocking the given hitbox, if any.
  BaseEntity? getBlockingEntity(
    Rect hitbox, {
    List<BaseEntity>? ignoredEntities,
  }) {
    for (final building in _buildings) {
      if (ignoredEntities != null && ignoredEntities.contains(building)) {
        continue;
      }

      // DO NOT block if the building is destroyed
      if (building.isDestroyed) continue;

      // DO NOT block if it's an open door
      if (building is DoorEntity && building.isOpen) continue;

      final bRect = building.toRect();
      if (hitbox.left < bRect.right &&
          hitbox.right > bRect.left &&
          hitbox.top < bRect.bottom &&
          hitbox.bottom > bRect.top) {
        return building;
      }
    }
    return null;
  }

  /// Registers a building for collision tracking.
  void registerBuilding(BaseEntity building) {
    if (!_buildings.contains(building)) {
      _buildings.add(building);
    }
  }

  /// Returns all registered buildings (for optimized lookups)
  List<BaseEntity> getBuildings() => _buildings;

  /// Unregisters a building from collision tracking.
  void unregisterBuilding(BaseEntity building) {
    _buildings.remove(building);
  }

  /// Unregisters a door from LoS tracking.
  void unregisterDoor(DoorEntity door) {
    final tx = (door.position.x / 32.0).floor();
    final ty = (door.position.y / 32.0).floor();
    doorMap.remove(math.Point(tx, ty));
  }

  /// Unregisters a bed from room tracking.
  void unregisterBed(BedEntity bed) {
    roomBeds.remove(bed.roomID);
    roomFog.remove(bed.roomID);
  }

  /// Registers a building slot for AI lookup.
  void registerBuildingSlot(BaseEntity slot) {
    if (!buildingSlots.contains(slot)) {
      buildingSlots.add(slot);
    }
  }

  /// Registers a building slot.
  void unregisterBuildingSlot(BaseEntity slot) {
    buildingSlots.remove(slot);
  }

  /// Optimized lookup for buildings in a specific room
  Iterable<BaseEntity> getBuildingsInRoom(String roomID) {
    if (roomID.isEmpty) return const [];
    // Only return buildings that are NOT destroyed
    return _buildings.where((b) => b.roomID == roomID && !b.isDestroyed);
  }

  /// Registers a turret for global tracking (e.g., room-specific fire limits).

  void registerTurret(BaseEntity turret) {
    if (!turrets.contains(turret)) {
      turrets.add(turret);
    }
  }

  /// Unregisters a turret.
  void unregisterTurret(BaseEntity turret) {
    turrets.remove(turret);
  }

  /// Generates a flow field (Dijkstra map) for the given room.
  /// Used by AI hunters to navigate to their beds.
  List<List<int>>? getFlowField(String roomID) {
    if (roomID.isEmpty) return null;

    // 1. LRU Cache Management
    if (_flowFieldCache.containsKey(roomID)) {
      _flowFieldLRU.remove(roomID);
      _flowFieldLRU.add(roomID);
      return _flowFieldCache[roomID];
    }

    final bed = roomBeds[roomID];
    if (bed == null) return null;

    final targetX = (bed.position.x / 32).floor();
    final targetY = (bed.position.y / 32).floor();

    final List<List<int>> field = List.generate(
      gridW,
      (_) => List.generate(gridH, (_) => 9999),
    );

    // Using a simple queue for BFS-style Dijkstra since weights are uniform (1 or 50)
    // For even better performance, we could use a PriorityQueue from collection package,
    // but for 40x40, BFS with a basic list is fast enough if we don't sort inside the loop.
    final queue = <math.Point<int>>[math.Point(targetX, targetY)];
    field[targetX][targetY] = 0;

    while (queue.isNotEmpty) {
      // Find node with lowest distance (Dijkstra)
      // This MUST be done every iteration for the flow field weights (1, 2, 100) to work.
      queue.sort((a, b) => field[a.x][a.y].compareTo(field[b.x][b.y]));
      
      final curr = queue.removeAt(0);
      final dist = field[curr.x][curr.y];

      for (final dir in [
        const math.Point(0, 1),
        const math.Point(0, -1),
        const math.Point(1, 0),
        const math.Point(-1, 0),
      ]) {
        final next = math.Point(curr.x + dir.x, curr.y + dir.y);
        if (next.x >= 0 && next.x < gridW && next.y >= 0 && next.y < gridH) {
          if (!wallGrid[next.x][next.y]) {
            // WEIGHTED PENALTY:
            // 1. Same room = 1
            // 2. Hallway (empty roomID) = 2 (AI prefers staying in rooms/target path)
            // 3. Foreign Room Door = 100 (Can exit, but won't enter as shortcut)
            int weight = 1;
            final door = doorMap[next];
            if (door != null && door.roomID != roomID) {
              weight = 100;
            } else if (getRoomIDAt(
              Vector2(next.x * 32.0, next.y * 32.0),
            ).isEmpty) {
              weight = 2;
            }

            final newDist = dist + weight;
            if (newDist < field[next.x][next.y]) {
              field[next.x][next.y] = newDist;
              if (!queue.contains(next)) queue.add(next);
            }
          }
        }
      }
    }

    // 2. Cache the result for future hunters
    // Finalize LRU Cache
    if (_flowFieldLRU.length >= _maxFlowFieldCache) {
      final oldest = _flowFieldLRU.removeAt(0);
      _flowFieldCache.remove(oldest);
    }
    _flowFieldCache[roomID] = field;
    _flowFieldLRU.add(roomID);

    return field;
  }

  /// Wipes caches and re-initializes the game world to recover from lag.
  /// Does NOT reset MatchManager state, so no progress is lost.
  void safeRefresh() {
    // 1. Clear Engine Caches
    Flame.images.clearCache();
    Flame.assets.clearCache();
    _flowFieldCache.clear();
    _flowFieldLRU.clear();

    // 2. Visual Feedback
    world.add(
      FloatingFeedback(
        label: 'OPTIMIZING...',
        color: Colors.cyanAccent,
        position: player.position,
        icon: Icons.auto_fix_high_rounded,
        duration: 2.0,
      ),
    );

    PerformanceManager.instance.resetLagWarning();
  }

  @override
  void update(double dt) {
    PerformanceManager.instance.updateFPS(dt);
    super.update(dt);

    // Update global building slot pulse (More subtle: slower speed and lower peak opacity)
    _pulseTimer += dt;
    // Speed reduced, Peak further reduced (0.15 instead of 0.2)
    slotOpacity =
        ((math.sin(_pulseTimer * (math.pi / 3.0)) + 1) /
        13.0); // Range [0.0, 0.15]

    // 1. Fog of War: Update player's current room in MatchManager
    final currentRoom = getRoomIDAt(player.position);
    if (MatchManager.instance.currentRoomID != currentRoom) {
      MatchManager.instance.setCurrentRoom(currentRoom);
    }

    // EVICTION LOGIC: Continuously check if player is trespassing in an AI's room
    if (_evictionMessageCooldown > 0) _evictionMessageCooldown -= dt;

    if (currentRoom.isNotEmpty) {
      final bed = roomBeds[currentRoom];
      if (bed != null && bed.isOccupied && !bed.owner!.hasCategory('player')) {
        if (bed.roomDoor != null) {
          // TELEPORT: Move player to the hallway (where roomID is empty and no obstacles)
          final safePos = _findSafeHallwayPosition(bed.roomDoor!.position);
          player.position = safePos;

          // THROW FEEDBACK: Only once every 2 seconds to avoid the "text wall" spam
          if (_evictionMessageCooldown <= 0) {
            _evictionMessageCooldown = 2.0;
            world.add(
              FloatingFeedback(
                label: 'Tenant kicked you out!',
                color: Colors.orangeAccent,
                position: player.position.clone(),
                icon: Icons.gavel,
              ),
            );
          }
        }
      }
    }

    // Drive the frame-independent match logic (coins, energy, ticks)
    MatchManager.instance.update(dt);
  }

  /// Returns the room ID at the given world position.
  String getRoomIDAt(Vector2 position) {
    final tx = (position.x / 32).floor();
    final ty = (position.y / 32).floor();
    return tileRoomMap[math.Point(tx, ty)] ?? '';
  }

  /// Helper to find a safe hallway position near a door.
  /// Ensures the target is NOT in a room, NOT a wall, and NOT a building slot.
  Vector2 _findSafeHallwayPosition(Vector2 doorPos) {
    // Candidates: 48px (1.5 tiles) in each cardinal direction
    final List<Vector2> candidates = [
      doorPos + Vector2(0, 48), // Down
      doorPos + Vector2(0, -48), // Up
      doorPos + Vector2(48, 0), // Right
      doorPos + Vector2(-48, 0), // Left
    ];

    for (final pos in candidates) {
      // 1. Is it a hallway? (roomID must be empty)
      if (getRoomIDAt(pos).isNotEmpty) continue;

      // 2. Is it physically blocked? (Walls/Buildings)
      // We check a small box at the target position
      final checkRect = Rect.fromCenter(
        center: pos.toOffset(),
        width: 16,
        height: 16,
      );

      if (isPositionBlocked(checkRect)) continue;

      // 3. Is it a building slot? (We don't want to stand on slots)
      bool isOnSlot = buildingSlots.any(
        (slot) => slot.toRect().overlaps(checkRect),
      );
      if (isOnSlot) continue;

      // Found a safe spot!
      return pos;
    }

    // fallback if everything is weirdly blocked (rare)
    return doorPos + Vector2(0, 64);
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

  /// Spawns a building slot at the given position.
  BuildingSlotEntity spawnBuildingSlot(Vector2 pos, String roomID) {
    return BuildingSlotEntity(position: pos, roomID: roomID);
  }

  /// Spawns the Dream Monster at a random spawn point.
  void _spawnMonster() {
    if (monsterSpawnPoints.isEmpty) return;
    final spawnPoint =
        monsterSpawnPoints[math.Random().nextInt(monsterSpawnPoints.length)];
    world.add(MonsterEntity(position: spawnPoint));
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
    stopwatch.dispose();
    super.onRemove();
  }

  /// Finds the shortest path between two positions using BFS on the wallGrid.
  /// Ignores dynamic buildings (doors, turrets) so the monster can navigate to them.
  /// Flood-fill to find all walkable tiles connected to a starting point,
  /// stopped by walls and doors.
  Set<math.Point<int>> _floodFillRoom(
    int startX,
    int startY, {
    Set<math.Point<int>>? doorTiles,
  }) {
    final Set<math.Point<int>> tiles = {};
    final List<math.Point<int>> queue = [math.Point(startX, startY)];
    final visited = <math.Point<int>>{math.Point(startX, startY)};

    // Get all doors to use as boundaries
    final boundaries =
        doorTiles ??
        _buildings
            .whereType<DoorEntity>()
            .map(
              (d) => math.Point(
                (d.position.x / 32).floor(),
                (d.position.y / 32).floor(),
              ),
            )
            .toSet();

    while (queue.isNotEmpty) {
      final curr = queue.removeLast();
      tiles.add(curr);

      for (final dir in [
        const math.Point(0, 1),
        const math.Point(0, -1),
        const math.Point(1, 0),
        const math.Point(-1, 0),
      ]) {
        final next = math.Point(curr.x + dir.x, curr.y + dir.y);

        if (next.x >= 0 &&
            next.x < gridW &&
            next.y >= 0 &&
            next.y < gridH &&
            !visited.contains(next)) {
          visited.add(next);

          // Stop if it's a wall or a door
          if (!wallGrid[next.x][next.y] && !boundaries.contains(next)) {
            queue.add(next);
          }
        }
      }
    }
    return tiles;
  }

  List<Vector2> getShortestPath(Vector2 start, Vector2 end) {
    final startX = (start.x / 32).floor().clamp(0, gridW - 1);
    final startY = (start.y / 32).floor().clamp(0, gridH - 1);
    final endX = (end.x / 32).floor().clamp(0, gridW - 1);
    final endY = (end.y / 32).floor().clamp(0, gridH - 1);

    if (startX == endX && startY == endY) return [];

    final startPoint = math.Point(startX, startY);
    final endPoint = math.Point(endX, endY);

    final openSet = <math.Point<int>>[startPoint];
    final cameFrom = <math.Point<int>, math.Point<int>>{};
    final gScore = <math.Point<int>, int>{startPoint: 0};
    final fScore = <math.Point<int>, int>{
      startPoint: _heuristic(startPoint, endPoint),
    };

    while (openSet.isNotEmpty) {
      // Find node in openSet with lowest fScore
      var current = openSet[0];
      var minF = fScore[current] ?? 999999;
      for (final node in openSet) {
        final f = fScore[node] ?? 999999;
        if (f < minF) {
          minF = f;
          current = node;
        }
      }

      if (current == endPoint) {
        return _reconstructPath(cameFrom, current);
      }

      openSet.remove(current);

      for (final neighbor in _getNeighbors(current)) {
        // WEIGHTED COST: Hallway = 1, Door = 50, Wall = Blocked
        final weight = _getTileWeight(neighbor, endPoint);
        if (weight >= 9999) continue;

        final tentativeGScore = (gScore[current] ?? 999999) + weight;
        if (tentativeGScore < (gScore[neighbor] ?? 999999)) {
          cameFrom[neighbor] = current;
          gScore[neighbor] = tentativeGScore;
          fScore[neighbor] = tentativeGScore + _heuristic(neighbor, endPoint);
          if (!openSet.contains(neighbor)) {
            openSet.add(neighbor);
          }
        }
      }
    }

    return [];
  }

  int _heuristic(math.Point<int> a, math.Point<int> b) {
    return (a.x - b.x).abs() + (a.y - b.y).abs();
  }

  int _getTileWeight(math.Point<int> p, math.Point<int> target) {
    if (wallGrid[p.x][p.y]) return 9999; // Wall is impassable

    // 1. Check for Doors (Boundary/Barrier)
    final door = doorMap[p];
    if (door != null && !door.isOpen && !door.isDestroyed) {
      // If the door IS the target tile, we allow it with cost 1 so we can stand on it to attack
      if (p == target) return 1;
      return 50; // High cost to break through a door
    }

    // 2. PERFORMANCE OPTIMIZATION: Check for other buildings (Turrets, Generators, etc.)
    // We only penalize them slightly so the monster prefers walking around,
    // but isn't strictly blocked if there's no other path.
    for (final b in _buildings) {
      if (b.isDestroyed) continue;
      if (b is DoorEntity) continue; // Already handled above

      final tx = (b.position.x / 32).floor();
      final ty = (b.position.y / 32).floor();
      if (tx == p.x && ty == p.y) {
        if (p == target) return 1;
        return 10; // Medium penalty for non-core buildings
      }
    }

    return 1; // Standard floor tile
  }

  List<math.Point<int>> _getNeighbors(math.Point<int> p) {
    final neighbors = <math.Point<int>>[];
    if (p.x > 0) neighbors.add(math.Point(p.x - 1, p.y));
    if (p.x < gridW - 1) neighbors.add(math.Point(p.x + 1, p.y));
    if (p.y > 0) neighbors.add(math.Point(p.x, p.y - 1));
    if (p.y < gridH - 1) neighbors.add(math.Point(p.x, p.y + 1));
    return neighbors;
  }

  List<Vector2> _reconstructPath(
    Map<math.Point<int>, math.Point<int>> cameFrom,
    math.Point<int> current,
  ) {
    final path = <Vector2>[
      Vector2(current.x * 32.0 + 16, current.y * 32.0 + 16),
    ];
    var curr = current;
    while (cameFrom.containsKey(curr)) {
      curr = cameFrom[curr]!;
      path.add(Vector2(curr.x * 32.0 + 16, curr.y * 32.0 + 16));
    }
    return path.reversed.toList();
  }
}

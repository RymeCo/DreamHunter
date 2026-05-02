import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/game/entities/bed_entity.dart';
import 'package:dreamhunter/game/entities/building_slot_entity.dart';
import 'package:dreamhunter/services/game/match_manager.dart';

/// A simple Fog of War component that hides unoccupied rooms.
/// Rooms are revealed if:
/// 1. They are occupied by any Hunter (Player or AI).
/// 2. The Player is physically inside the room.
class FogOfWar extends PositionComponent
    with HasGameReference<DreamHunterGame> {
  final Map<String, _RoomFog> _fogs = {};

  FogOfWar() : super(priority: 1000); // Above map, below UI

  @override
  void onMount() {
    super.onMount();
    _initializeFogs();
  }

  void _initializeFogs() {
    // Find all unique room IDs from beds AND slots to ensure coverage
    final beds = game.world.children.whereType<BedEntity>();
    final slots = game.world.children.whereType<BuildingSlotEntity>();

    final roomIDs = beds
        .map((b) => b.roomID)
        .followedBy(slots.map((s) => s.roomID))
        .where((id) => id.isNotEmpty && id != 'BuildingSlot')
        .toSet();

    debugPrint('[FOG] Initializing fogs for rooms: $roomIDs');

    for (final roomID in roomIDs) {
      final fog = _RoomFog(roomID: roomID);
      _fogs[roomID] = fog;
      add(fog);
    }
  }

  /// Marks a room as "bloody" because a hunter died there.
  void markDeath(String roomID) {
    if (roomID.isEmpty) return;
    _fogs[roomID]?.isBloody = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final playerRoom = MatchManager.instance.currentRoomID;

    // Use cached roomBeds for O(1) room occupancy check
    for (final fog in _fogs.values) {
      bool shouldReveal = false;

      // Reveal if occupied (O(1) lookup)
      final bed = game.roomBeds[fog.roomID];
      if (bed != null && bed.isOccupied) {
        shouldReveal = true;
      }

      // Reveal if player is in this room (even if not sleeping)
      if (playerRoom == fog.roomID) {
        shouldReveal = true;
      }

      fog.revealed = shouldReveal;
    }
  }
}

class _RoomFog extends PositionComponent
    with HasGameReference<DreamHunterGame> {
  final String roomID;
  bool revealed = false;
  bool isBloody = false;
  double opacity = 1.0;
  
  /// The cohesive path representing the room's actual shape (L-shapes, etc.)
  Path _roomPath = Path();
  bool _pathInitialized = false;

  _RoomFog({required this.roomID}) : super(priority: 1000);

  @override
  void onMount() {
    super.onMount();
    _calculateRoomPath();
  }

  void _calculateRoomPath() {
    final elements = game.world.children.where((e) {
      if (e is BedEntity && e.roomID == roomID) return true;
      if (e is BuildingSlotEntity && e.roomID == roomID) return true;
      return false;
    });

    if (elements.isEmpty) return;

    final newPath = Path();
    for (final e in elements) {
      final pos = (e as PositionComponent).position;
      final size = e.size;
      // Add each 32x32 tile to the unified path
      newPath.addRect(Rect.fromLTWH(pos.x, pos.y, size.x, size.y));
    }
    
    _roomPath = newPath;
    _pathInitialized = true;
  }

  @override
  void render(Canvas canvas) {
    if (opacity <= 0 || !_pathInitialized) return;

    final Color baseColor = isBloody ? Colors.red : Colors.black;

    // ARTISTIC FIX: Use a single drawPath call for the entire room shape.
    // This prevents the "grid" artifact (overlapping alpha) and follows 
    // the room's non-square geometry (L-shapes, etc.) exactly.

    // 1. Outer "Haze" (Smooth edge)
    // We use a thick stroke with a round join to create a "glow/haze" effect 
    // at the room boundaries where they touch the walls.
    final hazePaint = Paint()
      ..color = baseColor.withValues(alpha: opacity * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.drawPath(_roomPath, hazePaint);

    // 2. Inner Core (Solid fog)
    // This fills the middle of the room with a flat color as requested.
    final fillPaint = Paint()
      ..color = baseColor.withValues(alpha: opacity * 0.7)
      ..style = PaintingStyle.fill;

    canvas.drawPath(_roomPath, fillPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Dynamic path update if elements were missed during mount
    if (!_pathInitialized) {
      _calculateRoomPath();
    }

    if (revealed) {
      opacity = (opacity - dt * 3.0).clamp(0.0, 1.0);
    } else {
      opacity = (opacity + dt * 2.0).clamp(0.0, 1.0);
    }
  }
}

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
      // Let's create a fog overlay for each room
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

    for (final fog in _fogs.values) {
      final bed = game.world.children
          .whereType<BedEntity>()
          .where((b) => b.roomID == fog.roomID)
          .firstOrNull;

      bool shouldReveal = false;

      // Reveal if occupied
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
  double _pulseTimer = 0;
  final List<Rect> _elementRects = [];

  _RoomFog({required this.roomID}) : super(priority: 1000);

  @override
  void onMount() {
    super.onMount();
    _calculateElementRects();
  }

  void _calculateElementRects() {
    _elementRects.clear();
    // Find all beds and slots for this room
    final elements = game.world.children.where((e) {
      if (e is BedEntity && e.roomID == roomID) return true;
      if (e is BuildingSlotEntity && e.roomID == roomID) return true;
      return false;
    });

    for (final e in elements) {
      final pos = (e as PositionComponent).position;
      final size = e.size;
      // Store the rect for each individual element (Bed or Slot)
      _elementRects.add(Rect.fromLTWH(pos.x, pos.y, size.x, size.y));
    }
  }

  @override
  void render(Canvas canvas) {
    if (opacity <= 0 || _elementRects.isEmpty) return;

    // Use a hazy/blurry paint (Darker as requested)
    final Color baseColor = isBloody ? Colors.red : Colors.black;

    // Subtle Pulse Logic: Grows/shrinks slightly at the edges
    final double pulseScale = 1.0 + (math.sin(_pulseTimer * 2.0) * 0.05);

    for (final rect in _elementRects) {
      // Draw a hazy "blur" rect over each individual element
      final paint = Paint()
        ..color = baseColor
            .withValues(alpha: opacity * 0.8) // Increased opacity for darkness
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          10.0,
        ); // Slightly more blur for depth

      // Slightly pulsed rect
      final pulsedRect = Rect.fromCenter(
        center: rect.center,
        width: rect.width * pulseScale,
        height: rect.height * pulseScale,
      );

      canvas.drawRect(pulsedRect, paint);

      // Add a darker core so it's not just a flat blur
      canvas.drawRect(
        rect,
        Paint()..color = baseColor.withValues(alpha: opacity * 0.5),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt;

    // Retry calculation if we missed some elements during mount
    if (_elementRects.isEmpty) {
      _calculateElementRects();
    }

    if (revealed) {
      opacity = (opacity - dt * 3.0).clamp(0.0, 1.0);
    } else {
      opacity = (opacity + dt * 2.0).clamp(0.0, 1.0);
    }
  }
}

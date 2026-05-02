import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/services/game/match_manager.dart';

/// A highly optimized Fog of War component that renders an entire room
/// in a single batch using a Flutter Path.
class RoomFogLayer extends PositionComponent with HasGameReference<DreamHunterGame> {
  final String roomID;
  final Set<math.Point<int>> tiles;
  
  double _opacity = 0.85;
  bool _isBloody = false;
  double _deathTimer = 0.0;
  
  late final Path _path;
  late final Paint _paint;

  RoomFogLayer({
    required this.roomID,
    required this.tiles,
  }) : super(
          position: Vector2.zero(),
          priority: 2200,
        );

  @override
  void onLoad() {
    super.onLoad();
    _path = Path();
    for (final tile in tiles) {
      _path.addRect(Rect.fromLTWH(tile.x * 32.0, tile.y * 32.0, 32.0, 32.0));
    }
    
    _paint = Paint()
      ..color = const Color(0xFF1A1A1A).withValues(alpha: _opacity)
      ..style = PaintingStyle.fill;
  }

  void markDeath() {
    _isBloody = true;
    _deathTimer = 8.0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_deathTimer > 0) {
      _deathTimer -= dt;
    }

    final playerRoom = MatchManager.instance.currentRoomID;
    bool shouldReveal = false;

    // 1. Reveal if Player is in this room
    if (playerRoom == roomID) {
      shouldReveal = true;
    }

    // NEW: Physical Reveal (Fallback for bleeding fog or mismatched IDs)
    final playerTile = math.Point(
      (game.player.position.x / 32.0).floor().toInt(),
      (game.player.position.y / 32.0).floor().toInt(),
    );
    if (tiles.contains(playerTile)) {
      shouldReveal = true;
    }

    // 2. Reveal if an ALIVE hunter is in this room (Sleeping)
    final bed = game.roomBeds[roomID];
    if (bed != null && bed.isOccupied && !bed.isDestroyed) {
      shouldReveal = true;
    }

    // 3. Reveal if any AI hunter is currently in this room
    for (final ai in game.aiHunters) {
      if (!ai.isDestroyed && ai.roomID == roomID) {
        shouldReveal = true;
        break;
      }
    }

    // 4. Death Buffer
    if (_deathTimer > 0) {
      shouldReveal = true;
    }

    // Smooth transition
    final targetOpacity = shouldReveal ? 0.0 : 0.85;
    if (_opacity != targetOpacity) {
      final step = dt * 3.0;
      if (_opacity < targetOpacity) {
        _opacity = (_opacity + step).clamp(0, 0.85);
      } else {
        _opacity = (_opacity - step).clamp(0, 0.85);
      }
      
      final Color baseColor = _isBloody ? const Color(0xFF220000) : const Color(0xFF1A1A1A);
      _paint.color = baseColor.withValues(alpha: _opacity);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_opacity > 0) {
      canvas.drawPath(_path, _paint);
    }
  }
}

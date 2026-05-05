import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/entities/door_entity.dart';
import 'package:dreamhunter/game/entities/fridge_entity.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/game/game_config.dart';

/// A HUD button that toggles manual repair mode for the current room.
class RepairButton extends PositionComponent
    with HasGameReference<DreamHunterGame>, TapCallbacks, HasPaint {
  bool _isToggled = false;
  double _activeTimer = 0;
  double _errorFlashTimer = 0;
  late final _CooldownOverlay _cooldownOverlay;

  RepairButton()
    : super(size: Vector2.all(48), anchor: Anchor.bottomRight, priority: 1000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Use a simple circle with a wrench emoji on top
    final bg = CircleComponent(
      radius: size.x / 2,
      paint: Paint()..color = Colors.black.withValues(alpha: 0.5),
      position: size / 2,
      anchor: Anchor.center,
    );
    add(bg);

    final wrench = TextComponent(
      text: '🔧',
      textRenderer: TextPaint(style: const TextStyle(fontSize: 24)),
      position: size / 2,
      anchor: Anchor.center,
    );
    add(wrench);

    _cooldownOverlay = _CooldownOverlay(size: size);
    add(_cooldownOverlay);
  }

  @override
  void onMount() {
    super.onMount();
    // Move up and more towards the center
    position = Vector2(game.size.x - 48, game.size.y - 80);
  }

  @override
  void onTapDown(TapDownEvent event) {
    // REQUIREMENT: Not clickable if not sleeping
    if (!game.player.isSleeping) return;

    if (game.player.repairCooldown > 0 && !_isToggled) {
      // Show "unavailable" visual flash manually to avoid effect crashes
      _errorFlashTimer = 0.3;
      HapticManager.instance.heavy();
      return;
    }

    _isToggled = !_isToggled;
    AudioManager.instance.playClick();
    HapticManager.instance.light();

    if (_isToggled) {
      _activeTimer = 10.0; // Start 10s active duration
    } else {
      // Start cooldown when turning OFF manually
      game.player.repairCooldown = GameConfig.repairCooldown;
      _activeTimer = 0;
    }

    _updateVisualState();
    _updateRoomRepairs();
  }

  void _updateVisualState() {
    if (!game.player.isSleeping) {
      // Disabled look: Low opacity
      scale = Vector2.all(0.9);
      paint.color = Colors.white.withValues(alpha: 0.3);
      return;
    }

    if (_errorFlashTimer > 0) {
      // Error flash: Red tint
      paint.color = Colors.red.withValues(alpha: 1.0);
      scale = Vector2.all(1.2);
      return;
    }

    if (_isToggled) {
      scale = Vector2.all(1.1);
      paint.color = Colors.white.withValues(alpha: 1.0);
    } else {
      scale = Vector2.all(1.0);
      paint.color = Colors.white.withValues(alpha: 0.7);
    }
  }

  void _updateRoomRepairs() {
    final roomID = MatchManager.instance.currentRoomID;
    if (roomID.isEmpty) return;

    final buildings = game.world.children
        .whereType<DoorEntity>()
        .where((d) => d.roomID == roomID)
        .cast<BaseEntity>()
        .followedBy(
          game.world.children
              .whereType<FridgeEntity>()
              .where((f) => f.roomID == roomID)
              .cast<BaseEntity>(),
        );

    for (final b in buildings) {
      // Repair ONLY active if both toggled ON AND sleeping
      b.isBeingRepaired = _isToggled && game.player.isSleeping;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_errorFlashTimer > 0) {
      _errorFlashTimer -= dt;
    }

    // Update Timers
    if (_isToggled) {
      _activeTimer = (_activeTimer - dt).clamp(0, 20);
      if (_activeTimer <= 0) {
        // AUTO-TIMEOUT: Repair ends after 20s
        _isToggled = false;
        game.player.repairCooldown = GameConfig.repairCooldown;
        _updateVisualState();
        _updateRoomRepairs();
      }
      // Show active duration progress (draining)
      _cooldownOverlay.progress = _activeTimer / 20.0;
      _cooldownOverlay.isActiveIndicator = true;
    } else {
      // Show cooldown progress (filling)
      _cooldownOverlay.progress =
          game.player.repairCooldown / GameConfig.repairCooldown;
      _cooldownOverlay.isActiveIndicator = false;
    }

    // Constantly update visual state and room repairs based on sleeping/toggle
    _updateVisualState();

    if (_isToggled) {
      final roomID = MatchManager.instance.currentRoomID;
      // Auto-disable if player moves out of room, dies, OR wakes up
      if (roomID.isEmpty ||
          game.player.isDestroyed ||
          !game.player.isSleeping) {
        _isToggled = false;
        game.player.repairCooldown = GameConfig.repairCooldown;
        _activeTimer = 0;
        _updateVisualState();
        _updateRoomRepairs();
      } else {
        _updateRoomRepairs();
      }
    }
  }
}

class _CooldownOverlay extends PositionComponent
    with HasGameReference<DreamHunterGame> {
  double progress = 0; // 0 to 1
  bool isActiveIndicator = false;

  _CooldownOverlay({required super.size});

  @override
  void render(Canvas canvas) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = isActiveIndicator
          ? Colors.greenAccent.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // Draw the circular sweep
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, true, paint);
  }
}

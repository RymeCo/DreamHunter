import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/widgets/game/build_menu_dialog.dart';
import 'package:dreamhunter/game/entities/generator_entity.dart';
import 'package:dreamhunter/game/entities/turret_entity.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';

/// A slot in a dorm room where building can be placed.
/// Only visible and interactive if the player has claimed the room.
class BuildingSlotEntity extends BaseEntity with TapCallbacks {
  final String roomID;
  late final TextComponent _plusText;
  bool _isVisible = false;
  double _pulseTimer = 0;

  BuildingSlotEntity({required super.position, required this.roomID})
    : super(size: Vector2.all(32), anchor: Anchor.topLeft) {
    addCategory('building_slot');
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Visual: A simple '+' icon
    _plusText = TextComponent(
      text: '+',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_plusText);

    // Initial visibility check
    _updateVisibility();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateVisibility();

    if (_isVisible) {
      _pulseTimer += dt;
      // Opacity Pulse: Sin wave from 0.0 to 0.5 (semi-transparent) with a 3 second period
      final double opacity =
          ((sin(_pulseTimer * (pi / 1.5)) + 1) / 4); // Range [0.0, 0.5]

      _plusText.textRenderer = TextPaint(
        style: TextStyle(
          color: Colors.white.withValues(alpha: opacity),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  void _updateVisibility() {
    final bool isMyRoom = MatchManager.instance.currentRoomID == roomID;

    if (isMyRoom != _isVisible) {
      _isVisible = isMyRoom;
    }
  }

  @override
  void renderTree(Canvas canvas) {
    if (!_isVisible) return;
    super.renderTree(canvas);
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!_isVisible) return;

    AudioManager.instance.playClick();
    HapticManager.instance.light();

    // Show Building Selection Menu
    BuildMenuDialog.show(
      game.buildContext!,
      onBuildSelected: (buildingId) {
        if (buildingId == 'generator') {
          final generator = GeneratorEntity(
            position: position.clone(),
            roomID: roomID,
          );
          game.world.add(generator);
          removeFromParent();
        } else if (buildingId == 'turret') {
          final turret = TurretEntity(position: position + (size / 2));
          game.world.add(turret);
          removeFromParent();
        }
      },
    );
  }
}

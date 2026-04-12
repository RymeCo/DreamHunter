import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../haunted_dorm_game.dart';
import '../objects/bed.dart';
import '../actors/player.dart';

class BuildingSlot extends PositionComponent
    with TapCallbacks, HasGameReference<HauntedDormGame> {
  bool isOccupied = false;
  Bed? associatedBed;
  int roomID = -1;
  late final TextComponent _plusText;

  BuildingSlot({
    required super.position,
    required super.size,
    this.associatedBed,
  });

  @override
  Future<void> onLoad() async {
    _plusText = TextComponent(
      text: '+',
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.2), // Fainter visibility
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      anchor: Anchor.center,
      position: size / 2,
    );
    _plusText.scale = Vector2.zero();
    add(_plusText);

    // SUBTLE & SLOW: Slow breathing effect
    _plusText.add(
      ScaleEffect.to(
        Vector2.all(1.08), // Only 8% growth
        EffectController(
          duration: 1.5,
          reverseDuration: 1.5,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // SMART ROOM ISOLATION:
    // Only show "+" if player's current room ID matches this slot's room ID.
    final bool isClaimed =
        game.player.state == PlayerState.sleeping &&
        game.player.currentBed != null &&
        game.player.currentBed!.roomID == roomID;

    if (isClaimed && !isOccupied && roomID != -1) {
      if (_plusText.scale == Vector2.zero()) _plusText.scale = Vector2.all(1.0);
    } else {
      if (_plusText.scale != Vector2.zero()) _plusText.scale = Vector2.zero();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    final bool isClaimed =
        game.player.state == PlayerState.sleeping &&
        game.player.currentBed == associatedBed;

    if (isClaimed && !isOccupied) {
      game.activeSlot = this;
      game.overlays.add('BuildMenu');
    }
  }
}

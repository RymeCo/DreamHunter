import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';

/// A static bed building.
/// Characters cannot walk through the bed due to the 'building' category.
/// Shows a "Sleep" popup when the player is nearby.
class BedEntity extends BaseEntity with HasGameReference<DreamHunterGame> {
  late final TextComponent _popupText;
  double _popupAlpha = 0.0;
  final double _fadeSpeed = 5.0; // Speed of the fade animation

  BedEntity({
    required super.position,
  }) : super(
          size: Vector2.all(32),
          anchor: Anchor.topLeft,
        ) {
    addCategory('bed');
    addCategory('building');
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Load visual sprite
    final sprite = await Sprite.load('game/economy/bed-32x32.png');
    add(SpriteComponent(
      sprite: sprite,
      size: size,
    ));

    // Initialize popup text
    _popupText = TextComponent(
      text: 'Sleep',
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x / 2, -4),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.transparent, // Start transparent
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 4),
          ],
        ),
      ),
    );
    add(_popupText);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Check distance to player for popup visibility
    final bedCenter = position + (size / 2);
    final playerPos = game.player.position;
    final distance = bedCenter.distanceTo(playerPos);

    // Manual fade logic instead of OpacityEffect to prevent crashes
    if (distance < 48) {
      _popupAlpha = (_popupAlpha + dt * _fadeSpeed).clamp(0.0, 1.0);
    } else {
      _popupAlpha = (_popupAlpha - dt * _fadeSpeed).clamp(0.0, 1.0);
    }

    // Update text color with the new alpha
    if (_popupAlpha > 0) {
      _popupText.textRenderer = TextPaint(
        style: TextStyle(
          color: Colors.white.withValues(alpha: _popupAlpha),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: _popupAlpha), blurRadius: 4),
          ],
        ),
      );
    } else {
      _popupText.textRenderer = TextPaint(
        style: const TextStyle(color: Colors.transparent),
      );
    }
  }
}

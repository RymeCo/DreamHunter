import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../haunted_dorm_game.dart';
import '../actors/player.dart';

/// A mixin that adds a clickable prompt when the player is nearby.
mixin Interactable on SpriteComponent, HasGameReference<HauntedDormGame>
    implements TapCallbacks {
  late final TextComponent prompt;
  bool _isPlayerNear = false;
  String get interactionAction;
  void onInteract();

  void setupInteractable() {
    prompt = TextComponent(
      text: interactionAction,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black54,
        ),
      ),
      anchor: Anchor.center,
      position: Vector2(width / 2, -15),
    );
    prompt.scale = Vector2.all(0);
    add(prompt);
  }

  void updateInteractable(Vector2 playerPosition, double range) {
    final distance = (playerPosition - position).length;
    // Hide prompt if player is already sleeping
    final isSleeping = game.player.state == PlayerState.sleeping;
    final near = distance < range && !isSleeping;

    if (near != _isPlayerNear) {
      _isPlayerNear = near;
      prompt.scale = near ? Vector2.all(1.0) : Vector2.all(0);
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    if (!_isPlayerNear) return false;
    return point.x >= -20 &&
        point.x <= width + 20 &&
        point.y >= -20 &&
        point.y <= height + 20;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_isPlayerNear) {
      onInteract();
    }
  }
}

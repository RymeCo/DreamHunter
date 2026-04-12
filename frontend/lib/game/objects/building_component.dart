import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../haunted_dorm_game.dart';
import '../core/interactable.dart';

/// Base class for all placeable structures in the game.
/// Provides common functionality for leveling, health, and interaction.
abstract class BuildingComponent extends SpriteComponent
    with HasGameReference<HauntedDormGame>, TapCallbacks, Interactable {
  int level;
  double maxHealth;
  late double currentHealth;
  late RectangleComponent hpBar;

  BuildingComponent({
    required super.position,
    required super.size,
    this.level = 1,
    this.maxHealth = 100,
  }) {
    currentHealth = maxHealth;
  }

  @override
  FutureOr<void> onLoad() async {
    setupInteractable();
    _setupHPBar();
    return super.onLoad();
  }

  void _setupHPBar() {
    hpBar = RectangleComponent(
      size: Vector2(width, 4),
      position: Vector2(0, -5),
      paint: Paint()..color = Colors.greenAccent,
    );
    hpBar.scale = Vector2.zero(); // Hidden by default
    add(hpBar);
  }

  @override
  void update(double dt) {
    super.update(dt);
    updateInteractable(game.player.position, 50.0);
    _updateHPDisplay();
  }

  void _updateHPDisplay() {
    if (currentHealth < maxHealth) {
      hpBar.scale = Vector2.all(1.0);
      hpBar.width = width * (currentHealth / maxHealth).clamp(0, 1);
      hpBar.paint.color = currentHealth < (maxHealth * 0.3)
          ? Colors.redAccent
          : Colors.greenAccent;
    } else {
      hpBar.scale = Vector2.zero();
    }
  }

  void takeDamage(double amount) {
    currentHealth -= amount;

    // Hit flash effect
    add(
      ColorEffect(
        const Color(0x55FF0000),
        EffectController(duration: 0.1, reverseDuration: 0.1),
      ),
    );

    if (currentHealth <= 0) {
      currentHealth = 0;
      onDestroyed();
    }
  }

  void repair(double amount) {
    currentHealth = (currentHealth + amount).clamp(0, maxHealth);
  }

  /// Override this to handle specific destruction logic.
  void onDestroyed() {
    removeFromParent();
  }

  /// Scale up/down effect for interactions or upgrades.
  void triggerBounceEffect() {
    add(
      ScaleEffect.to(
        Vector2.all(1.1),
        EffectController(duration: 0.1, reverseDuration: 0.1),
      ),
    );
  }
}

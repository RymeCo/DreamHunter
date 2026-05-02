import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/entities/door_entity.dart';
import 'package:dreamhunter/game/components/wrench_component.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';

/// A defensive building that protects the room's door.
/// It "freezes" the door by adding a shield equal to the door's max HP.
class FridgeEntity extends BaseEntity with TapCallbacks {
  @override
  final String roomID;
  late final SpriteComponent _spriteComponent;
  DoorEntity? _targetDoor;
  double _regenTimer = 0;

  FridgeEntity({required super.position, required this.roomID})
    : super(size: Vector2.all(32), anchor: Anchor.center) {
    addCategory('building');
    addCategory('fridge');
    maxHp = 50.0;
    hp = maxHp;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDestroyed) {
      isBeingRepaired = false;
      return;
    }

    // Manual Repair Visualization
    if (isBeingRepaired && children.whereType<WrenchComponent>().isEmpty) {
      add(WrenchComponent()..position = size / 2);
    }

    // Manual Repair Logic: 2% every 1s (ONLY when isBeingRepaired is true)
    if (isBeingRepaired && hp < maxHp) {
      _regenTimer += dt;
      if (_regenTimer >= 1.0) {
        _regenTimer = 0;
        hp = (hp + maxHp * 0.02).clamp(0, maxHp);
      }
    } else {
      _regenTimer = 0;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final sprite = await game.loadSprite('game/defenses/fridge-64x64.png');
    _spriteComponent = SpriteComponent(
      sprite: sprite,
      size: Vector2.all(32), // Scale down to fit the slot
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_spriteComponent);

    // Visual feedback: A persistent breathing pulse to simulate "freezing"
    _spriteComponent.add(
      ScaleEffect.to(
        Vector2.all(1.05),
        EffectController(
          duration: 1.2,
          reverseDuration: 1.2,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );

    // Find the door for this room
    _findDoor();
    _applyEffect();
  }

  void _findDoor() {
    // Find all doors and pick the one with matching roomID
    for (final child in game.world.children) {
      if (child is DoorEntity && child.roomID == roomID) {
        _targetDoor = child;
        break;
      }
    }
  }

  void _applyEffect() {
    if (_targetDoor != null && !_targetDoor!.isDestroyed) {
      _targetDoor!.setShield(_targetDoor!.maxHp, _targetDoor!.maxHp);

      // Visual feedback: Go big then shrink
      _spriteComponent.add(
        ScaleEffect.to(
          Vector2.all(1.5),
          EffectController(duration: 0.2, reverseDuration: 0.2),
        ),
      );
    }
  }

  @override
  void onRemove() {
    // When the fridge is destroyed, remove the shield completely
    if (_targetDoor != null && !_targetDoor!.isDestroyed) {
      _targetDoor!.setShield(0, 0);
    }
    super.onRemove();
  }

  @override
  void onTapUp(TapUpEvent event) {
    // Fridge can be tapped to "refresh" or just show info
    AudioManager.instance.playClick();
    HapticManager.instance.light();

    // Maybe show a simple status message in the future.
    // For now, let's just re-apply the shield if it was broken.
    _applyEffect();
  }
}

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/entities/door_entity.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';

/// A defensive building that protects the room's door.
/// It "freezes" the door by adding a shield equal to the door's max HP.
class FridgeEntity extends BaseEntity with TapCallbacks {
  @override
  final String roomID;
  late final SpriteComponent _spriteComponent;
  DoorEntity? _targetDoor;

  FridgeEntity({required super.position, required this.roomID})
      : super(size: Vector2.all(32), anchor: Anchor.center) {
    addCategory('building');
    addCategory('fridge');
    maxHp = 1.0;
    hp = maxHp;
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
      _targetDoor!.setShield(_targetDoor!.maxHp);
    }
  }

  @override
  void onRemove() {
    // When the fridge is destroyed, should we remove the shield?
    // User didn't specify, but usually, the effect ends when the building is gone.
    if (_targetDoor != null && !_targetDoor!.isDestroyed) {
      _targetDoor!.setShield(0);
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

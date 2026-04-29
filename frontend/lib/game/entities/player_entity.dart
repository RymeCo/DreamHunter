import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/behaviors/player_movement_behavior.dart';
import 'package:dreamhunter/game/ui/dynamic_joystick.dart';
import 'package:dreamhunter/services/economy/shop_manager.dart';
import 'package:dreamhunter/data/item_registry.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/game/components/floating_feedback.dart';

/// The playable character entity.
class PlayerEntity extends BaseEntity {
  final DynamicJoystick joystick;
  late final SpriteComponent _spriteComponent;
  late final Sprite _sleepingSprite;

  bool isSleeping = false;
  int _lastTickCount = 0;

  PlayerEntity({required this.joystick})
    : super(
        size: Vector2(32, 48), // Standard character size
        anchor: Anchor.center,
      ) {
    addCategory('player');
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1. Determine which character is selected
    final characterId = ShopManager.instance.selectedCharacterId;
    final item = ItemRegistry.get(characterId);

    // 2. Load the sprite (Asset is already pre-cached by GameLoader)
    final imagePath =
        item?.image.replaceFirst('assets/images/', '') ??
        'game/characters/max_front-32x48.png';
    final sprite = await Sprite.load(imagePath);

    // Create cropped sleeping head sprite (top 24 pixels to include shoulders/chest)
    _sleepingSprite = Sprite(
      sprite.image,
      srcPosition: sprite.srcPosition,
      srcSize: Vector2(32, 24),
    );

    // 3. Add visual representation
    _spriteComponent = SpriteComponent(sprite: sprite, size: size);
    add(_spriteComponent);

    // 4. Add movement behavior
    add(PlayerMovementBehavior(joystick: joystick));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isSleeping) {
      final currentTicks = MatchManager.instance.tickCount;
      if (currentTicks > _lastTickCount) {
        _lastTickCount = currentTicks;

        // Spawn Coin feedback every tick
        final income = MatchManager.instance.incomePerTick;
        add(
          FloatingFeedback(
            label: '+$income',
            icon: Icons.monetization_on_rounded,
            color: Colors.amberAccent,
            position: Vector2(22, 0),
          ),
        );

        // Spawn Zzz every 3 ticks (slower pacing for atmosphere)
        if (currentTicks % 3 == 0) {
          add(
            FloatingFeedback(
              label: math.Random().nextBool() ? 'z' : 'Z',
              color: Colors.white,
              position: Vector2(10, 0),
            ),
          );
        }
      }
    }
  }

  /// Puts the player to sleep in the specified bed.
  void sleep(Vector2 bedPosition) {
    isSleeping = true;

    // 0. Reset scale to normal to prevent mirrored particles
    scale.x = 1.0;

    // 1. Notify MatchManager (Unmasks the economy HUD)
    MatchManager.instance.setHunterSleeping(true);

    // 2. Remove movement logic permanently
    children.whereType<PlayerMovementBehavior>().forEach(
      (b) => b.removeFromParent(),
    );

    // 3. Stop camera from following the player
    game.camera.stop();

    // 4. Change visuals to just the head
    _spriteComponent.sprite = _sleepingSprite;
    _spriteComponent.size = Vector2(32, 24);
    size = Vector2(32, 24); // Shrink component size too

    // 5. Teleport to bed (aligned to pillow)
    // Pillow is at the very top of the bed. We move Y to 4 so the head touches the top edge.
    position = bedPosition + Vector2(16, 4);

    _lastTickCount = MatchManager.instance.tickCount;
  }
}

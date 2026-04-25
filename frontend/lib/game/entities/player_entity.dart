import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/behaviors/player_movement_behavior.dart';
import 'package:dreamhunter/game/ui/dynamic_joystick.dart';
import 'package:dreamhunter/services/economy/shop_manager.dart';
import 'package:dreamhunter/data/item_registry.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';

/// The playable character entity.
class PlayerEntity extends BaseEntity with HasGameReference<DreamHunterGame> {
  final DynamicJoystick joystick;
  late final SpriteComponent _spriteComponent;
  late final Sprite _sleepingSprite;
  
  bool isSleeping = false;

  PlayerEntity({required this.joystick}) : super(
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
    final imagePath = item?.image.replaceFirst('assets/images/', '') ?? 'game/characters/max_front-32x48.png';
    final sprite = await Sprite.load(imagePath);
    
    // Create cropped sleeping head sprite (top 24 pixels to include shoulders/chest)
    _sleepingSprite = Sprite(
      sprite.image,
      srcPosition: sprite.srcPosition,
      srcSize: Vector2(32, 24),
    );

    // 3. Add visual representation
    _spriteComponent = SpriteComponent(
      sprite: sprite,
      size: size,
    );
    add(_spriteComponent);

    // 4. Add movement behavior
    add(PlayerMovementBehavior(joystick: joystick));
  }

  /// Puts the player to sleep in the specified bed.
  void sleep(Vector2 bedPosition) {
    isSleeping = true;
    
    // 1. Remove movement logic permanently
    children.whereType<PlayerMovementBehavior>().forEach((b) => b.removeFromParent());
    
    // 2. Stop camera from following the player
    game.camera.stop();

    // 3. Change visuals to just the head
    _spriteComponent.sprite = _sleepingSprite;
    _spriteComponent.size = Vector2(32, 24);
    size = Vector2(32, 24); // Shrink component size too
    
    // 4. Teleport to bed (aligned to pillow)
    // Pillow is at the very top of the bed. We move Y to 4 so the head touches the top edge.
    position = bedPosition + Vector2(16, 4);

    // 5. Add Zzz particle spawner
    add(TimerComponent(
      period: 1.5,
      repeat: true,
      onTick: () => add(ZzzParticle()),
    ));
  }
}

/// A simple drifting "z" particle that fades out.
class ZzzParticle extends PositionComponent {
  late final TextComponent _text;
  double _alpha = 1.0;
  final double _speed = 15.0;
  final double _fadeSpeed = 0.5;
  final double _driftX = math.Random().nextDouble() * 10 - 5; // Random slight horizontal drift

  ZzzParticle() : super(anchor: Anchor.center, position: Vector2(16, 0));

  @override
  void onLoad() {
    _text = TextComponent(
      text: math.Random().nextBool() ? 'z' : 'Z',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      ),
    );
    add(_text);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Move up and drift
    position.y -= _speed * dt;
    position.x += _driftX * dt;

    // Fade out
    _alpha -= _fadeSpeed * dt;
    if (_alpha <= 0) {
      removeFromParent();
    } else {
      // Manual alpha update for text renderer
      _text.textRenderer = TextPaint(
        style: TextStyle(
          color: Colors.white.withValues(alpha: _alpha),
          fontSize: 8 + (1.0 - _alpha) * 4, // Grow slightly as it floats up
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black.withValues(alpha: _alpha), blurRadius: 2)],
        ),
      );
    }
  }
}

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/behaviors/monster_ai_behavior.dart';
import 'package:dreamhunter/game/components/floating_feedback.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:flame/collisions.dart';

class MonsterEntity extends BaseEntity {
  double speed = 96.0; // Increased by 20% from 80.0
  double attackDamage = 6.0; // Reduced from 10.0 (-40%) for early game balance
  int monsterLevel = 1;
  int experience = 0;

  late final SpriteComponent _spriteComponent;
  late final _MonsterHealthBar _healthBar;

  late Sprite _idleSprite;
  late Sprite _backSprite;
  late Sprite _rightSprite;
  late Sprite _rightBackSprite;

  MonsterEntity({super.position})
    : super(size: Vector2(32, 48), anchor: Anchor.bottomCenter) {
    addCategory('monster');
    maxHp = 100.0;
    hp = maxHp;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // COMBAT HITBOX: The monster needs a full-body hitbox to be hit by projectiles.
    // The base class only adds a foot-level hitbox for navigation.
    add(
      RectangleHitbox(
        size: Vector2(size.x * 0.8, size.y * 0.8),
        position: Vector2(size.x * 0.1, size.y * 0.1),
      ),
    );

    // Load sprites
    _idleSprite = await Sprite.load('game/monsters/ghost_idle-32x48.png');
    _backSprite = await Sprite.load('game/monsters/ghost_back-32x48.png');
    _rightSprite = await Sprite.load('game/monsters/ghost_right-32x48.png');
    _rightBackSprite = await Sprite.load(
      'game/monsters/ghost_right_back-32x48.png',
    );

    _spriteComponent = SpriteComponent(sprite: _idleSprite, size: size);
    add(_spriteComponent);

    // Add health bar
    _healthBar = _MonsterHealthBar();
    add(_healthBar);

    // Add AI behavior
    add(MonsterAIBehavior());
  }

  void updateSprite(Vector2 direction) {
    if (direction.length < 0.1) {
      _spriteComponent.sprite = _idleSprite;
      return;
    }

    final isRight = direction.x > 0.1;
    final isLeft = direction.x < -0.1;
    final isUp = direction.y < -0.1;
    final isDown = direction.y > 0.1;

    // Flip horizontally based on X direction
    if (isLeft) {
      scale.x = -1;
    } else if (isRight) {
      scale.x = 1;
    }

    if (isUp) {
      if (isRight || isLeft) {
        _spriteComponent.sprite = _rightBackSprite;
      } else {
        _spriteComponent.sprite = _backSprite;
      }
    } else if (isDown) {
      if (isRight || isLeft) {
        _spriteComponent.sprite = _rightSprite;
      } else {
        _spriteComponent.sprite = _idleSprite;
      }
    } else {
      // Horizontal only
      _spriteComponent.sprite = _rightSprite;
    }
  }

  void gainExperience(int amount) {
    experience += amount;
    final int nextLevelXP = (100 * math.pow(1.1, monsterLevel - 1)).floor();
    if (experience >= nextLevelXP) {
      experience -= nextLevelXP;
      _levelUp();
    }
  }

  void _levelUp() {
    monsterLevel++;
    maxHp *= 1.2;
    hp = maxHp; // Full heal on level up
    attackDamage = 6.0 * math.pow(1.20, monsterLevel - 1);

    debugPrint('[MONSTER] LEVEL UP! Now Level $monsterLevel. HP: $maxHp, Damage: ${attackDamage.toStringAsFixed(1)}');

    // Visual feedback for level up: Grow and flash
    pulse(1.8);
    flashColor(Colors.redAccent);

    // Announce Level Up
    game.world.add(
      FloatingFeedback(
        label: 'LEVEL UP: $monsterLevel',
        color: Colors.redAccent,
        position: position + Vector2(0, -size.y),
        icon: Icons.keyboard_double_arrow_up,
      ),
    );
  }

  /// Flashes the monster a certain color.
  void flashColor(Color color) {
    _spriteComponent.add(
      ColorEffect(
        color,
        EffectController(duration: 0.2, reverseDuration: 0.2),
        opacityTo: 0.5,
      ),
    );
  }

  /// Pulses the monster's scale.
  void pulse(double scale) {
    add(
      ScaleEffect.to(
        Vector2.all(scale),
        EffectController(
          duration: 0.1,
          reverseDuration: 0.3,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  @override
  void takeDamage(double amount) {
    super.takeDamage(amount);
    _healthBar.updateVisuals();
  }

  @override
  void destroy() {
    if (isDestroyed) return;
    super.destroy();
    
    // Notify MatchManager that the monster is dead (Victory!)
    MatchManager.instance.winMatch();
    debugPrint('[MONSTER] Monster defeated! Game over (Win).');
  }
}

class _MonsterHealthBar extends RectangleComponent
    with ParentIsA<MonsterEntity> {
  late final RectangleComponent _fill;

  _MonsterHealthBar()
    : super(
        position: Vector2(4, -8),
        size: Vector2(24, 4),
        paint: Paint()..color = Colors.black.withValues(alpha: 0.7),
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _fill = RectangleComponent(
      size: Vector2(24, 4),
      paint: Paint()..color = Colors.redAccent,
    );
    add(_fill);
  }

  void updateVisuals() {
    _fill.size.x = (parent.hp / parent.maxHp) * 24.0;
  }
}

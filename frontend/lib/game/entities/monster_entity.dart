import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/behaviors/monster_ai_behavior.dart';
import 'package:dreamhunter/game/components/floating_feedback.dart';

class MonsterEntity extends BaseEntity {
  double speed = 96.0; // Increased by 20% from 80.0
  double attackDamage = 5.0;
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
    attackDamage = 5.0 * math.pow(1.15, monsterLevel - 1);

    // Visual feedback for level up: Grow, pulse, and color flash
    add(
      ScaleEffect.to(
        Vector2.all(1.8),
        EffectController(
          duration: 0.1,
          reverseDuration: 0.3,
          curve: Curves.easeOut,
        ),
      ),
    );

    add(
      ColorEffect(
        Colors.redAccent,
        EffectController(duration: 0.2, reverseDuration: 0.2),
        opacityTo: 0.5,
      ),
    );

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

  @override
  void takeDamage(double amount) {
    super.takeDamage(amount);
    _healthBar.updateVisuals();
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

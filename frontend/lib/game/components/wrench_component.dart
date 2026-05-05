import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';

/// A visual indicator that an entity is being repaired.
/// Displays a wrench emoji that moves as if turning a knob.
class WrenchComponent extends PositionComponent with ParentIsA<BaseEntity> {
  WrenchComponent() : super(anchor: Anchor.center, priority: 100);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final wrench = TextComponent(
      text: '🔧',
      textRenderer: TextPaint(style: const TextStyle(fontSize: 16)),
      anchor: Anchor.center,
    );
    add(wrench);

    // Wrench "turning" animation: Rotate back and forth
    wrench.add(
      RotateEffect.to(
        0.5,
        EffectController(
          duration: 0.3,
          reverseDuration: 0.3,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );

    // Subtle scale pulse
    wrench.add(
      ScaleEffect.to(
        Vector2.all(1.2),
        EffectController(
          duration: 0.6,
          reverseDuration: 0.6,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Auto-remove if not being repaired
    if (!parent.isBeingRepaired || parent.isDestroyed) {
      removeFromParent();
    }
  }
}

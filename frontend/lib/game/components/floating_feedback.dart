import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A reusable, high-quality floating feedback component.
/// Fixes overlapping text/icons by using a container-based layout.
class FloatingFeedback extends PositionComponent {
  final String label;
  final IconData? icon;
  final Color color;
  final bool isCoin;

  // Animation state
  double _timer = 0;
  double _alpha = 1.0;
  final double duration;
  final double upSpeed;
  final double _driftAmplitude = 6.0; // More drift
  final double _driftFrequency = 3.0;
  final double _randomOffset = math.Random().nextDouble() * 100;
  final double baseScale;

  FloatingFeedback({
    required this.label,
    this.icon,
    required this.color,
    required super.position,
    this.isCoin = false,
    this.duration = 1.5,
    this.upSpeed = 30.0,
    this.baseScale = 1.0,
  }) : super(anchor: Anchor.center, priority: 9999);

  @override
  void onLoad() {
    final tp = TextPaint(
      style: TextStyle(
        color: color,
        fontSize: 10, // Larger
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 4),
          Shadow(color: Colors.black, offset: Offset(1, 1)),
        ],
      ),
    );

    // Create a container to hold everything and make it easy to center
    final container = PositionComponent();
    add(container);

    // 1. Label Text
    final textComponent = TextComponent(text: label, textRenderer: tp);
    container.add(textComponent);

    final textWidth = textComponent.size.x;
    double totalWidth = textWidth;

    // 2. Optional Icon or Coin Sprite
    if (isCoin || icon != null) {
      final double iconSize = 10.0;
      final Component iconComp;

      if (isCoin) {
        // Create a "Sprite-like" coin using components
        iconComp = CircleComponent(
          radius: iconSize / 2,
          position: Vector2(textWidth + 4, 0),
          paint: Paint()..color = Colors.amber,
          children: [
            // Inner circle for detail
            CircleComponent(
              radius: iconSize / 3,
              position: Vector2(iconSize / 6, iconSize / 6),
              paint: Paint()..color = Colors.orangeAccent,
            ),
          ],
        );
      } else {
        iconComp = TextComponent(
          text: String.fromCharCode(icon!.codePoint),
          position: Vector2(textWidth + 4, 0),
          textRenderer: TextPaint(
            style: TextStyle(
              color: color,
              fontSize: iconSize,
              fontFamily: icon!.fontFamily,
              package: icon!.fontPackage,
              shadows: const [
                Shadow(color: Colors.black, blurRadius: 4),
                Shadow(color: Colors.black, offset: Offset(1, 1)),
              ],
            ),
          ),
        );
      }

      container.add(iconComp);
      totalWidth = textWidth + 4 + iconSize;
    }

    // Center the container relative to this component's position
    container.position = Vector2(-totalWidth / 2, -5);

    // 3. Initial "Pop" scaling
    scale = Vector2.all(0.4);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;

    // Movement: Upward + Sine drift
    position.y -= _speedCurve(_timer) * upSpeed * dt;
    position.x +=
        math.sin(_timer * _driftFrequency + _randomOffset) *
        _driftAmplitude *
        dt;

    // Pop-in and Fade-out
    if (_timer < 0.2) {
      // Fast pop-in
      final t = _timer / 0.2;
      scale = Vector2.all((0.4 + 0.8 * t) * baseScale); // scaled base
    } else if (_timer < 0.4) {
      // Settle
      final t = (_timer - 0.2) / 0.2;
      scale = Vector2.all((1.2 - 0.2 * t) * baseScale);
    } else {
      // Fade out
      final fadeStart = duration * 0.5; // Start fading halfway through
      if (_timer > fadeStart) {
        _alpha = (1.0 - (_timer - fadeStart) / (duration - fadeStart)).clamp(
          0.001,
          1.0,
        );
        scale = Vector2.all(_alpha * baseScale);
      }
    }

    if (_timer >= duration) {
      removeFromParent();
    }
  }

  double _speedCurve(double t) {
    return (1.0 - (t / duration) * 0.5).clamp(0.1, 1.0);
  }
}

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// A highly fluid, animated "floating" joystick.
/// It remains invisible until the user touches the screen, then pops in at the touch location.
class DynamicJoystick extends PositionComponent with HasPaint {
  final double baseRadius = 50.0;
  final double knobRadius = 20.0;
  
  late final CircleComponent _base;
  late final CircleComponent _knob;
  
  Vector2 _relativeDelta = Vector2.zero();
  Vector2 get relativeDelta => _relativeDelta;

  bool _isActive = false;
  bool get isActive => _isActive;

  double _currentOpacity = 0.0;
  final double _fadeSpeed = 8.0;

  DynamicJoystick() : super(size: Vector2.all(100), anchor: Anchor.center) {
    // Start invisible and scaled down
    scale = Vector2.all(0.5);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    _base = CircleComponent(
      radius: baseRadius,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.white.withValues(alpha: 0),
      position: size / 2,
    );
    
    _knob = CircleComponent(
      radius: knobRadius,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.white.withValues(alpha: 0),
      position: size / 2,
    );

    add(_base);
    add(_knob);
  }

  /// Starts the joystick at the touch location.
  void startDrag(Vector2 touchPosition) {
    _isActive = true;
    position = touchPosition;
    _relativeDelta = Vector2.zero();
    _knob.position = size / 2;

    // Pop in scale effect (this one works fine on PositionComponent)
    add(ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.2, curve: Curves.easeOutBack)));
  }

  /// Updates the knob position and calculates the movement delta.
  void updateDrag(Vector2 currentTouchPosition) {
    if (!_isActive) return;

    final dragVector = currentTouchPosition - position;
    final distance = dragVector.length;
    final clampedDistance = distance.clamp(0.0, baseRadius);
    
    if (distance > 0) {
      _relativeDelta = dragVector / distance * (clampedDistance / baseRadius);
    } else {
      _relativeDelta = Vector2.zero();
    }

    _knob.position = (size / 2) + (dragVector.normalized() * clampedDistance);
  }

  /// Ends the drag.
  void endDrag() {
    _isActive = false;
    _relativeDelta = Vector2.zero();

    // Fade out scale effect
    add(ScaleEffect.to(Vector2.all(0.5), EffectController(duration: 0.2, curve: Curves.easeIn)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Manual opacity animation
    if (_isActive) {
      _currentOpacity = (_currentOpacity + dt * _fadeSpeed).clamp(0.0, 1.0);
    } else {
      _currentOpacity = (_currentOpacity - dt * _fadeSpeed).clamp(0.0, 1.0);
    }

    // Apply opacity to children's paints
    _base.paint.color = Colors.white.withValues(alpha: _currentOpacity * 0.1);
    _knob.paint.color = Colors.white.withValues(alpha: _currentOpacity * 0.5);

    // If not active, spring the knob back to center
    if (!_isActive && _knob.position != (size / 2)) {
      _knob.position.lerp(size / 2, 0.2);
    }
  }
}

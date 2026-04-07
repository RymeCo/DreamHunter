import 'dart:async';
import 'package:flame/components.dart';
import '../haunted_dorm_game.dart';

class Generator extends SpriteComponent with HasGameReference<HauntedDormGame> {
  final int level;
  double _timer = 0;

  Generator({required super.position, required super.size, this.level = 1});

  @override
  FutureOr<void> onLoad() async {
    // Load based on level: generator_lv1, generator_lv2, etc.
    final name = 'generator_lv$level-32x32.png';
    sprite = await game.loadSprite('game/economy/$name');
    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Generate extra energy/coins every 1 second
    _timer += dt;
    if (_timer >= 1.0) {
      _timer = 0;
      game.player.energy += (level * 2); // Level 1 adds +2, Level 2 adds +4, etc.
    }
  }
}

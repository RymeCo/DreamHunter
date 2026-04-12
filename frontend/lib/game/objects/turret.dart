import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame/effects.dart';
import 'dart:math' as math;
import 'building_component.dart';
import '../actors/ghost.dart';

class Turret extends BuildingComponent {
  late final SpriteSheet _sheet;
  late final SpriteComponent _head;
  double _shootTimer = 0;

  Turret({required super.position, required super.size, super.level = 1})
    : super(maxHealth: 200);

  @override
  String get interactionAction => 'UPGRADE (Lv$level)';

  @override
  void onInteract() {
    game.activeTurret = this;
    game.overlays.add('UpgradeMenu');
  }

  @override
  FutureOr<void> onLoad() async {
    final sheetImage = await game.images.load(
      'game/defenses/turret_sheet-32x32.png',
    );
    _sheet = SpriteSheet(image: sheetImage, srcSize: Vector2.all(32));

    sprite = _sheet.getSprite(level - 1, 0);

    _head = SpriteComponent(
      sprite: _sheet.getSprite(level - 1, 1),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_head);

    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    prompt.text = interactionAction;

    final ghosts = game.level.children.whereType<Ghost>();
    if (ghosts.isNotEmpty) {
      final target = ghosts.first;
      final distance = (target.position - position).length;

      if (distance < 200) {
        final angle = math.atan2(
          target.position.y - (y + height / 2),
          target.position.x - (x + width / 2),
        );
        _head.angle = angle + (math.pi / 2);

        _shootTimer += dt;
        if (_shootTimer >= 0.8) {
          _shootTimer = 0;
          _fireProjectile(target);
        }
      }
    }
  }

  void _fireProjectile(Ghost target) {
    final bullet = SpriteComponent(
      sprite: _sheet.getSprite(level - 1, 2),
      size: Vector2.all(12),
      position: position + (size / 2),
      anchor: Anchor.center,
    );

    game.level.add(bullet);

    bullet.add(
      MoveToEffect(
        target.position,
        EffectController(duration: 0.3),
        onComplete: () {
          target.takeDamage(10.0 * level);
          bullet.removeFromParent();
        },
      ),
    );
  }

  void upgrade() {
    if (level < 9) {
      level++;
      sprite = _sheet.getSprite(level - 1, 0);
      _head.sprite = _sheet.getSprite(level - 1, 1);
      triggerBounceEffect();
    }
  }
}

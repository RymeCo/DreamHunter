import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame/events.dart';
import '../haunted_dorm_game.dart';
import '../core/interactable.dart';

class Turret extends SpriteComponent 
    with HasGameReference<HauntedDormGame>, TapCallbacks, Interactable {
  
  int level;
  late final SpriteSheet _sheet;
  late final SpriteComponent _head;

  Turret({required super.position, required super.size, this.level = 1});

  @override
  String get interactionAction => 'UPGRADE (Lv$level)';

  @override
  void onInteract() {
    game.activeTurret = this;
    game.overlays.add('UpgradeMenu');
  }

  @override
  FutureOr<void> onLoad() async {
    final sheetImage = await game.images.load('game/defenses/turret_sheet-32x32.png');
    _sheet = SpriteSheet(
      image: sheetImage,
      srcSize: Vector2.all(32),
    );

    // Set the base sprite
    sprite = _sheet.getSprite(level - 1, 0);

    // Create the rotating head as a child
    _head = SpriteComponent(
      sprite: _sheet.getSprite(level - 1, 1),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_head);

    setupInteractable();
    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    updateInteractable(game.player.position, 50.0);
    prompt.text = interactionAction;
  }

  void upgrade() {
    if (level < 9) {
      level++;
      sprite = _sheet.getSprite(level - 1, 0);
      _head.sprite = _sheet.getSprite(level - 1, 1);
    }
  }
}

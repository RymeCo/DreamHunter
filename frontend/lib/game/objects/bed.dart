import 'dart:async';
import 'package:flame/components.dart';
import 'building_component.dart';

class Bed extends BuildingComponent {
  final String orientation;
  int roomID = -1;

  Bed({
    required super.position,
    required super.size,
    this.orientation = 'North',
  }) : super(maxHealth: 200) {
    priority = 1;
  }

  @override
  String get interactionAction => 'SLEEP';

  @override
  void onInteract() {
    game.player.enterBed();
  }

  @override
  FutureOr<void> onLoad() async {
    size = Vector2.all(32);
    sprite = await game.loadSprite('game/economy/bed-32x32.png');
    return super.onLoad();
  }

  @override
  void onDestroyed() {
    if (game.player.currentBed == this) {
      game.gameState.setGameOver(victory: false);
    } else {
      super.onDestroyed();
    }
  }

  void setSleeping(bool sleeping) {}
}

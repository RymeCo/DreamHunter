import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../haunted_dorm_game.dart';
import '../core/interactable.dart';

class Bed extends SpriteComponent with HasGameReference<HauntedDormGame>, TapCallbacks, Interactable {
  final String orientation; // North, South, East, West

  Bed({
    required super.position, 
    required super.size, 
    this.orientation = 'North',
  });

  @override
  String get interactionAction => 'SLEEP';

  @override
  void onInteract() {
    game.player.enterBed();
  }

  @override
  FutureOr<void> onLoad() async {
    priority = 1;
    size = Vector2.all(32);
    sprite = await game.loadSprite('game/economy/bed-32x32.png');
    
    setupInteractable();

    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    updateInteractable(game.player.position, 50.0);
  }

  void setSleeping(bool sleeping) {
    // Logic for sleeping state (like ZZZ particles) can go here
  }
}

import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import '../haunted_dorm_game.dart';
import '../level/collision_block.dart';
import '../core/interactable.dart';
import 'bed.dart';

class Door extends SpriteComponent 
    with HasGameReference<HauntedDormGame>, TapCallbacks, Interactable {
  
  bool isOpen;
  late final Sprite _closedSprite;
  late final Sprite _openSprite;
  final CollisionBlock collisionBlock;
  Bed? associatedBed;

  Door({required Vector2 position, required Vector2 size, this.isOpen = true})
    : collisionBlock = CollisionBlock(
        position: position.clone(),
        size: size.clone(),
        isPassable: isOpen,
      ),
      super(position: position, size: size) {
    priority = 0;
  }

  @override
  String get interactionAction => isOpen ? 'CLOSE' : 'OPEN';

  @override
  void onInteract() {
    toggleDoor();
  }

  @override
  FutureOr<void> onLoad() async {
    _closedSprite = await game.loadSprite('game/defenses/door_wood-32x32.png');
    _openSprite = await game.loadSprite('game/defenses/door_wood_open-32x32.png');

    sprite = isOpen ? _openSprite : _closedSprite;
    setupInteractable();

    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    updateInteractable(game.player.position, 50.0);
    
    prompt.text = interactionAction;
  }

  void toggleDoor() {
    isOpen = !isOpen;
    collisionBlock.isPassable = isOpen;
    
    add(
      ScaleEffect.to(
        Vector2.all(1.1),
        EffectController(duration: 0.1, reverseDuration: 0.1),
        onComplete: () {
          sprite = isOpen ? _openSprite : _closedSprite;
        },
      ),
    );
  }

  void closeDoor() {
    if (isOpen) toggleDoor();
  }
}

import 'dart:async';
import 'package:flame/components.dart';
import 'building_component.dart';
import '../level/collision_block.dart';
import 'bed.dart';

class Door extends BuildingComponent {
  bool isOpen;
  late final Sprite _closedSprite;
  late final Sprite _openSprite;
  final CollisionBlock collisionBlock;
  Bed? associatedBed;
  int roomID = -1;

  Door({required Vector2 position, required Vector2 size, this.isOpen = true})
    : collisionBlock = CollisionBlock(
        position: position.clone(),
        size: size.clone(),
        isPassable: isOpen,
      ),
      super(position: position, size: size, maxHealth: 100) {
    priority = 0;
  }

  @override
  String get interactionAction => isOpen ? 'CLOSE' : 'REPAIR';

  @override
  void onInteract() {
    if (isOpen) {
      toggleDoor();
    } else {
      repairDoor();
    }
  }

  @override
  FutureOr<void> onLoad() async {
    _closedSprite = await game.loadSprite('game/defenses/door_wood-32x32.png');
    _openSprite = await game.loadSprite(
      'game/defenses/door_wood_open-32x32.png',
    );

    sprite = isOpen ? _openSprite : _closedSprite;
    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    prompt.text = interactionAction;
  }

  @override
  void takeDamage(double amount) {
    if (isOpen) return;
    super.takeDamage(amount);
    if (currentHealth <= 0) {
      toggleDoor(); // Break door (open it)
    }
  }

  void repairDoor() {
    if (game.player.energy >= 10) {
      game.player.energy -= 10;
      repair(50.0);
    }
  }

  void toggleDoor() {
    isOpen = !isOpen;
    collisionBlock.isPassable = isOpen;

    if (!isOpen) {
      // Cardinal Push Logic
      final player = game.player;
      final doorCenter = position + (size / 2);
      final diff = player.position - doorCenter;
      Vector2 push = (diff.x.abs() > diff.y.abs())
          ? Vector2(diff.x.sign * 48, 0)
          : Vector2(0, diff.y.sign * 48);
      player.position = doorCenter + push;
      currentHealth = maxHealth; // Reset HP when closing
    }

    triggerBounceEffect();
    sprite = isOpen ? _openSprite : _closedSprite;
  }

  void closeDoor() {
    if (isOpen) toggleDoor();
  }

  @override
  void onDestroyed() {
    // Doors don't get removed, they just open (break)
    isOpen = true;
    collisionBlock.isPassable = true;
    sprite = _openSprite;
    currentHealth = 0;
  }
}

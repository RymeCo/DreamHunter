import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../haunted_dorm_game.dart';
import '../objects/bed.dart';

class BuildingSlot extends SpriteComponent 
    with TapCallbacks, HasGameReference<HauntedDormGame> {
  
  bool isOccupied = false;
  Bed? associatedBed;

  BuildingSlot({
    required super.position,
    required super.size,
    this.associatedBed,
  });

  @override
  Future<void> onLoad() async {
    // Development placeholder for the grid slot
    sprite = await game.loadSprite('tiles/floor_tiles-32x32.png');
    // Slightly tint it so players know it's interactive
    paint = Paint()..color = Colors.white.withValues(alpha: 0.1);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (isOccupied) return;

    // Check if player is sleeping in the associated bed
    if (game.player.currentBed != associatedBed) {
      // Cannot build in a room you don't own
      return;
    }

    // Trigger Build Menu (We will implement this in Phase 3)
    game.overlays.add('BuildMenu');
  }
}

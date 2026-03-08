# DreamHunter Game Engine - Guide

This directory contains the core game logic built with the Flame engine.

## Core Components

### DreamHunterGame (`dreamhunter_game.dart`)
The main orchestrator of the game.
- **Usage**: Initialize with a `characterType` (e.g., 'lady', 'boy', 'man').
- **Features**: 
  - Manages the "Liquid Glass" joystick.
  - Handles camera following.
  - Orchestrates level loading and player instantiation.

### Player (`actors/player.dart`)
The main controllable character.
- **Constructor**: Requires a `JoystickComponent` and `characterType`. Optional `size` (defaults to 32x64).
- **Hitbox**: Fixed at 32x32 at the feet (`Anchor.bottomCenter`) to allow the head to overlap walls.
- **States**: Automatically swaps between `facing-front` and `facing-back` based on Y-axis movement. Flips horizontally based on X-axis movement.
- **Assets**: Requires assets in `assets/images/game/characters/<type>/` with naming pattern: `facing-<front|back> (<width>x<height>).png`.

### Level (`level/level.dart`)
Handles Tiled map integration.
- **Usage**: Initialize with `levelName` (matching a `.tmx` file in `assets/tiles/`) and a `Player` instance.
- **Requirements**:
  - `Spawnpoints` layer: Object with class `Player` for starting position.
  - `Collisions` layer: Objects to define non-passable areas.

### CollisionBlock (`level/collision_block.dart`)
An invisible component used to define boundaries.
- **Properties**: `isPassable` (defaults to false).

## Game Balance (`core/constants.dart`)
Centralized place for all magic numbers including player speed, ghost stats, and economy rates.

## Placeholder Directories
- `objects/`: For interactive map elements like doors and beds.
- `interface/`: For the Heads-Up Display (HUD).

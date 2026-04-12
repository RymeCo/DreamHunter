import 'dart:collection';
import 'package:flame/components.dart';

/// A simple BFS pathfinder for 32x32 grid navigation.
class Pathfinder {
  /// Finds the shortest path from [start] to [target] on a grid.
  /// [isWalkable] is a function that returns true if a tile coordinate (x,y) is clear.
  static List<Vector2>? findPath({
    required Vector2 start,
    required Vector2 target,
    required bool Function(int x, int y) isWalkable,
    int maxSearchDepth = 1000,
  }) {
    // Convert world positions to grid coordinates
    final startX = (start.x / 32).floor();
    final startY = (start.y / 32).floor();
    final targetX = (target.x / 32).floor();
    final targetY = (target.y / 32).floor();

    if (startX == targetX && startY == targetY) return [];

    final queue = Queue<_PathNode>();
    final visited = <String>{'$startX,$startY'};

    queue.add(_PathNode(startX, startY, null));

    int depth = 0;
    while (queue.isNotEmpty && depth < maxSearchDepth) {
      final current = queue.removeFirst();
      depth++;

      if (current.x == targetX && current.y == targetY) {
        return _reconstructPath(current);
      }

      final neighbors = [
        [0, 1],
        [0, -1],
        [1, 0],
        [-1, 0],
      ];

      for (final offset in neighbors) {
        final nx = current.x + offset[0];
        final ny = current.y + offset[1];
        final key = '$nx,$ny';

        if (!visited.contains(key) && isWalkable(nx, ny)) {
          visited.add(key);
          queue.add(_PathNode(nx, ny, current));
        }
      }
    }

    return null; // No path found
  }

  static List<Vector2> _reconstructPath(_PathNode goal) {
    final path = <Vector2>[];
    _PathNode? current = goal;
    while (current != null) {
      // Center of the 32x32 tile
      path.add(Vector2(current.x * 32.0 + 16, current.y * 32.0 + 16));
      current = current.parent;
    }
    return path.reversed.toList();
  }
}

class _PathNode {
  final int x;
  final int y;
  final _PathNode? parent;
  _PathNode(this.x, this.y, this.parent);
}

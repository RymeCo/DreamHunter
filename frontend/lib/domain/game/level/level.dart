import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';

class Level extends Component {
  final String fileName;
  final Vector2 destTileSize;
  late TiledComponent level;

  Level({required this.fileName, required this.destTileSize});

  @override
  FutureOr<void> onLoad() async {
    level = await TiledComponent.load(fileName, destTileSize);
    add(level);
    return super.onLoad();
  }
}

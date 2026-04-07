import 'package:flame/components.dart';

/// Extension to parse metadata from asset filenames.
/// Example: "bed_lv1-32x64.png" -> Vector2(32, 64)
extension SpriteNameParser on String {
  Vector2 extractSize() {
    // Look for the pattern -WxH (e.g., -32x64)
    final match = RegExp(r'-(\d+)x(\d+)').firstMatch(this);
    if (match != null) {
      final width = double.parse(match.group(1)!);
      final height = double.parse(match.group(2)!);
      return Vector2(width, height);
    }
    // Fallback to default 32x32 if no pattern is found
    return Vector2.all(32);
  }

  /// Extracts the base name without the size or extension.
  /// Example: "bed_lv1-32x64.png" -> "bed_lv1"
  String extractBaseName() {
    final nameWithoutExt = split('.').first;
    return nameWithoutExt.split('-').first;
  }
}

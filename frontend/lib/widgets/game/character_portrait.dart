import 'package:flutter/material.dart';

/// A utility widget that crops a 32x48 character sprite to show only the head/face.
class CharacterPortrait extends StatelessWidget {
  final String imagePath;
  final double size;
  final bool isGray;

  const CharacterPortrait({
    super.key,
    required this.imagePath,
    this.size = 32.0,
    this.isGray = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: FittedBox(
          alignment: Alignment.topCenter,
          fit: BoxFit.none,
          child: SizedBox(
            width: size,
            height: size * (48 / 32),
            child: ColorFiltered(
              colorFilter: isGray
                  ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                  : const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.multiply,
                    ),
              child: Image.asset(imagePath, fit: BoxFit.fill),
            ),
          ),
        ),
      ),
    );
  }
}

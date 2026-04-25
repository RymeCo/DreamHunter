import 'package:flutter/material.dart';

/// A performance-friendly vignette overlay to create a creepy atmosphere.
/// It uses a RadialGradient that fades from transparent in the center
/// to a deep, dark color at the edges.
class VignetteOverlay extends StatelessWidget {
  const VignetteOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.1),
              Colors.black.withValues(alpha: 0.4),
              Colors.black.withValues(alpha: 0.8),
              Colors.black,
            ],
            stops: const [0.0, 0.4, 0.6, 0.8, 1.0],
          ),
        ),
      ),
    );
  }
}

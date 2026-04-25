import 'package:flutter/material.dart';

/// A simple overlay that displays a countdown timer.
/// Syncs perfectly with Flame's engine via a ValueNotifier.
class GraceTimerOverlay extends StatelessWidget {
  final ValueNotifier<int> notifier;

  const GraceTimerOverlay({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (context, seconds, child) {
        if (seconds < 0) return const SizedBox.shrink();

        final String display = seconds == 0 ? 'RUN!' : '$seconds';
        final Color color = seconds == 0 ? Colors.redAccent : Colors.white;

        return Center(
          child: Text(
            display,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: color,
              fontSize: 80,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  offset: const Offset(4, 4),
                  blurRadius: 10,
                ),
                Shadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

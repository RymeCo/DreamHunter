import 'package:flutter/material.dart';

/// A match timer that remains hidden until the grace period is over.
/// Automatically formats seconds into a clean MM:SS display.
class MatchTimerOverlay extends StatelessWidget {
  final ValueNotifier<int> matchNotifier;
  final ValueNotifier<int> graceNotifier;

  const MatchTimerOverlay({
    super.key,
    required this.matchNotifier,
    required this.graceNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: graceNotifier,
      builder: (context, graceSeconds, child) {
        // Only show once the grace countdown (10..1..RUN!) is finished.
        if (graceSeconds >= 0) return const SizedBox.shrink();

        return ValueListenableBuilder<int>(
          valueListenable: matchNotifier,
          builder: (context, matchSeconds, child) {
            final minutes = (matchSeconds ~/ 60).toString().padLeft(2, '0');
            final seconds = (matchSeconds % 60).toString().padLeft(2, '0');

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Text(
                '$minutes:$seconds',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

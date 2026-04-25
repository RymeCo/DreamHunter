import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/core/theme/app_theme.dart';

/// A simple row for displaying stats (e.g., Level, XP, Coins) with an icon.
class StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double iconSize;

  const StatRow({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: iconSize),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// A standard progress bar used for tasks, loading, and XP.
class GameProgressBar extends StatelessWidget {
  final double percent;
  final Color? baseColor;
  final List<Color> gradientColors;
  final double height;

  const GameProgressBar({
    super.key,
    required this.percent,
    this.baseColor,
    this.gradientColors = const [Colors.deepPurpleAccent, Colors.purpleAccent],
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<GlassTheme>();
    final barPercent = percent.clamp(0.0, 1.0);

    return Stack(
      children: [
        // Background track
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color:
                baseColor ??
                Colors.white.withValues(alpha: glass?.baseOpacity ?? 0.1),
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
        // Progress fill
        FractionallySizedBox(
          widthFactor: barPercent,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(height / 2),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Standardized header for all game dialogs.
class GameDialogHeader extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final bool showCloseButton;
  final bool isCentered;

  const GameDialogHeader({
    super.key,
    required this.title,
    this.titleColor,
    this.showCloseButton = true,
    this.isCentered = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = titleColor ?? Colors.amberAccent;

    return Container(
      height: 56, // Fixed height to prevent dialog jumping
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: isCentered ? Alignment.center : Alignment.centerLeft,
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: accent,
                fontSize: 20,
                letterSpacing: 2,
                shadows: [
                  Shadow(color: accent.withValues(alpha: 0.4), blurRadius: 12),
                ],
              ),
            ),
          ),
          // Use Opacity to maintain layout but hide the button
          Opacity(
            opacity: showCloseButton ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !showCloseButton,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38),
                  onPressed: () {
                    HapticManager.instance.light();
                    AudioManager.instance.playClick();
                    Navigator.pop(context);
                  },
                  splashRadius: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A loading bar variant with a label and percentage indicator.
class GameLoadingBar extends StatelessWidget {
  final double progress;
  final String label;

  const GameLoadingBar({
    super.key,
    required this.progress,
    this.label = 'LOADING...',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 12,
                color: Colors.white70,
                letterSpacing: 2,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 14,
                color: Colors.cyanAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GameProgressBar(
          percent: progress,
          height: 12,
          gradientColors: const [Color(0xFFE92EF6), Color(0xFFCB1CC5)],
        ),
      ],
    );
  }
}

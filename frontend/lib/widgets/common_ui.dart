import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/core/theme/app_theme.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';

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
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
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
  final double? height;

  const GameDialogHeader({
    super.key,
    required this.title,
    this.titleColor,
    this.showCloseButton = true,
    this.isCentered = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final accent = titleColor ?? Colors.amberAccent;
    final h = height ?? 56.0;

    return Container(
      height: h,
      padding: EdgeInsets.symmetric(vertical: h > 40 ? 8.0 : 4.0),
      child: Row(
        mainAxisAlignment: isCentered
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: [
          // Fixed width spacer to balance the close button if centered
          if (isCentered && showCloseButton) SizedBox(width: h > 40 ? 48 : 40),

          Expanded(
            child: Text(
              title.toUpperCase(),
              textAlign: isCentered ? TextAlign.center : TextAlign.left,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: accent,
                fontSize: h > 40 ? 20 : 16,
                letterSpacing: 2,
                shadows: [
                  Shadow(color: accent.withValues(alpha: 0.4), blurRadius: 12),
                ],
              ),
              overflow: TextOverflow.ellipsis, // Prevent overlap
              maxLines: 1,
            ),
          ),

          if (showCloseButton)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white38),
              onPressed: () {
                HapticManager.instance.light();
                AudioManager.instance.playClick();
                Navigator.pop(context);
              },
              splashRadius: h > 40 ? 24 : 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else if (isCentered)
            SizedBox(width: h > 40 ? 48 : 40), // Spacer
        ],
      ),
    );
  }
}

/// Standardized full-page (or large dialog) wrapper for game screens.
/// This ensures Profile, Leaderboard, Settings, and Tasks all feel uniform.
class StandardGlassPage extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showCloseButton;
  final bool isCentered;
  final double? width;
  final double? height;
  final List<Widget>? footer;
  final EdgeInsets? padding;
  final bool isCompact;
  final bool isFullScreen;

  const StandardGlassPage({
    super.key,
    required this.title,
    required this.child,
    this.showCloseButton = true,
    this.isCentered = false,
    this.width,
    this.height,
    this.footer,
    this.padding,
    this.isCompact = false,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive sizing: Defaults to 90% of screen width (max 500) and 85% of screen height
    final responsiveWidth = isFullScreen
        ? screenWidth
        : (width ?? (screenWidth * 0.9).clamp(320.0, 500.0));
    final responsiveHeight = isFullScreen
        ? screenHeight
        : (height ?? (isCompact ? null : screenHeight * 0.85));

    return Center(
      child: LiquidGlassDialog(
        width: responsiveWidth,
        height: responsiveHeight,
        borderRadius: isFullScreen ? 0 : 20.0,
        padding:
            padding ??
            EdgeInsets.symmetric(
              horizontal: (isCompact || isFullScreen) ? 16 : 24,
              vertical: (isCompact || isFullScreen) ? 12 : 20,
            ),
        child: Column(
          mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            GameDialogHeader(
              title: title,
              showCloseButton: showCloseButton,
              isCentered: isCentered,
              height: (isCompact || isFullScreen) ? 40 : 56,
            ),
            SizedBox(height: (isCompact || isFullScreen) ? 8 : 12),
            if (isCompact) child else Expanded(child: child),
            if (footer != null) ...[
              SizedBox(height: (isCompact || isFullScreen) ? 12 : 16),
              ...footer!,
            ],
          ],
        ),
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

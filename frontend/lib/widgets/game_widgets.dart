import 'package:flutter/material.dart';

class StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double iconSize;
  final double fontSize;

  const StatRow({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.iconSize = 20,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: iconSize),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class GameProgressBar extends StatelessWidget {
  final double percent;
  final Color baseColor;
  final List<Color> gradientColors;
  final double height;

  const GameProgressBar({
    super.key,
    required this.percent,
    this.baseColor = Colors.black26,
    this.gradientColors = const [Colors.blueAccent, Colors.lightBlueAccent],
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
        FractionallySizedBox(
          widthFactor: percent.clamp(0.0, 1.0),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(height / 2),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class GameDialogHeader extends StatelessWidget {
  final String title;
  final Color titleColor;
  final VoidCallback onEmojiTap; // Optional for future expansions
  final bool showCloseButton;

  const GameDialogHeader({
    super.key,
    required this.title,
    this.titleColor = Colors.amberAccent,
    this.onEmojiTap = _noop,
    this.showCloseButton = true,
  });

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: titleColor,
              letterSpacing: 2,
              shadows: [
                Shadow(
                  color: titleColor.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          if (showCloseButton)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white38),
              onPressed: () => Navigator.pop(context),
              splashRadius: 20,
            ),
        ],
      ),
    );
  }
}

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
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GameProgressBar(
          percent: progress,
          height: 12,
          gradientColors: const [
            Color(0xFFE92EF6),
            Color(0xFFCB1CC5),
          ],
        ),
      ],
    );
  }
}

class AppLogo extends StatelessWidget {
  final double size;
  final bool animated;

  const AppLogo({
    super.key,
    this.size = 200,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/core/splash_logo.png',
          width: size,
          height: size,
          color: const Color.fromRGBO(169, 13, 200, 0.4),
          colorBlendMode: BlendMode.srcATop,
        ),
        Image.asset(
          'assets/images/core/splash_logo.png',
          width: size * 0.95,
          height: size * 0.95,
          color: const Color.fromRGBO(228, 159, 240, 0.9),
          colorBlendMode: BlendMode.modulate,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/audio_service.dart';

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
    this.gradientColors = const [Colors.deepPurpleAccent, Colors.purpleAccent],
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
  final bool isCentered;

  const GameDialogHeader({
    super.key,
    required this.title,
    this.titleColor = Colors.amberAccent,
    this.onEmojiTap = _noop,
    this.showCloseButton = true,
    this.isCentered = false,
  });

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: isCentered ? Alignment.center : Alignment.centerLeft,
            child: Text(
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
          ),
          if (showCloseButton)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white38),
                onPressed: () {
                  AudioService().playClick();
                  Navigator.pop(context);
                },
                splashRadius: 20,
              ),
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
          gradientColors: const [Color(0xFFE92EF6), Color(0xFFCB1CC5)],
        ),
      ],
    );
  }
}

class AppLogo extends StatelessWidget {
  final double size;
  final bool animated;

  const AppLogo({super.key, this.size = 200, this.animated = true});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/dashboard/core/splash_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class RouletteWheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> rewards;
  final double rotation;
  const RouletteWheelPainter({required this.rewards, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = (2 * math.pi) / rewards.length;

    // 1. Draw Arcs (Wheel background)
    for (int i = 0; i < rewards.length; i++) {
      final String colorStr = (rewards[i]['color'] as String).replaceFirst(
        '0x',
        '',
      );
      final baseColor = Color(int.parse(colorStr, radix: 16));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            baseColor.withValues(alpha: 0.9),
            baseColor.withValues(alpha: 0.5),
          ],
        ).createShader(rect);

      canvas.drawArc(rect, rotation + i * sweepAngle, sweepAngle, true, paint);
    }

    // 2. Draw Text (Radial Base-to-Center)
    for (int i = 0; i < rewards.length; i++) {
      canvas.save();

      // Move to center and rotate to the middle of the current segment
      canvas.translate(center.dx, center.dy);
      final segmentRotation = rotation + (i * sweepAngle) + (sweepAngle / 2);
      canvas.rotate(segmentRotation);

      final tp = TextPainter(
        text: TextSpan(
          text: rewards[i]['name'],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black87,
                blurRadius: 4,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Position text radially - 75% of the way out
      final xOffset = radius * 0.72;
      canvas.translate(xOffset, 0);

      // Rotate 90 degrees to align text base with the radius (perpendicular)
      canvas.rotate(math.pi / 2);

      // Paint centered
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(RouletteWheelPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

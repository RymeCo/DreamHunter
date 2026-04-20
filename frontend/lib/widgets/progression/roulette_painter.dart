import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Specialized CustomPainter for the Lucky Roulette wheel.
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

    for (int i = 0; i < rewards.length; i++) {
      final String colorStr =
          (rewards[i]['color'] as String).replaceFirst('0x', '');
      final baseColor = Color(int.parse(colorStr, radix: 16));

      final paint =
          Paint()
            ..shader = RadialGradient(
              colors: [
                baseColor.withValues(alpha: 0.95),
                baseColor.withValues(alpha: 0.6),
              ],
            ).createShader(rect);

      canvas.drawArc(rect, rotation + i * sweepAngle, sweepAngle, true, paint);
    }

    // Radial Text labels
    for (int i = 0; i < rewards.length; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      final segmentRotation = rotation + (i * sweepAngle) + (sweepAngle / 2);
      canvas.rotate(segmentRotation);

      final tp =
          TextPainter(
            text: TextSpan(
              text: rewards[i]['name'].toString().toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

      canvas.translate(radius * 0.75, 0);
      canvas.rotate(math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(RouletteWheelPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

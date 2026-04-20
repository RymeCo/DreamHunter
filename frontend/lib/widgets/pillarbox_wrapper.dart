import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/layout_baseline.dart';

/// Wraps the application to enforce the fixed portrait aspect ratio (500:850).
/// On wider screens, it adds "pillarbox" padding (Pure White or Pure Black) based on user settings.
class PillarboxWrapper extends StatelessWidget {
  final Widget child;

  const PillarboxWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LayoutBaseline.instance,
      builder: (context, _) {
        final bgColor = LayoutBaseline.instance.pillarboxColor;

        return Material(
          color: bgColor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;

              // Target: 500:850 aspect ratio
              final targetW = h * LayoutBaseline.targetAspectRatio;

              if (w > targetW) {
                // Screen is wider than our target portrait ratio: Apply Pillarboxing
                return Center(
                  child: SizedBox(
                    width: targetW,
                    height: h,
                    child: _buildInnerChild(context, targetW, h),
                  ),
                );
              } else {
                // Screen is narrower than or equal to our target: Fill width (Standard Portrait)
                return _buildInnerChild(context, w, h);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildInnerChild(BuildContext context, double w, double h) {
    // Override MediaQuery so the rest of the app thinks it's in a fixed-size container
    final data = MediaQuery.of(context);
    return MediaQuery(
      data: data.copyWith(
        size: Size(w, h),
        padding: EdgeInsets
            .zero, // Usually we don't want OS notches in windowed mode
        viewPadding: EdgeInsets.zero,
        viewInsets: data.viewInsets,
      ),
      child: ClipRect(child: child),
    );
  }
}

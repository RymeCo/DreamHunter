import 'package:flutter/material.dart';
import 'dart:math' as math;
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
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              // Calculate scale to fit the 500x850 target resolution within available space
              final scaleX = w / LayoutBaseline.targetWidth;
              final scaleY = h / LayoutBaseline.targetHeight;
              final scale = scaleX < scaleY ? scaleX : scaleY;

              // Update global scale factor for singleton consumers
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (LayoutBaseline.instance.scale != scale) {
                  LayoutBaseline.instance.updateScale(
                    scale * LayoutBaseline.targetHeight,
                  );
                }
              });

              // Map physical insets (notches, keyboards) to logical space
              final outerData = MediaQuery.of(context);
              final scaledWidth = LayoutBaseline.targetWidth * scale;
              final scaledHeight = LayoutBaseline.targetHeight * scale;
              final horizontalBar = (w - scaledWidth) / 2;
              final verticalBar = (h - scaledHeight) / 2;

              final mappedPadding = EdgeInsets.only(
                top: math.max(0, outerData.padding.top - verticalBar) / scale,
                bottom:
                    math.max(0, outerData.padding.bottom - verticalBar) / scale,
                left:
                    math.max(0, outerData.padding.left - horizontalBar) / scale,
                right:
                    math.max(0, outerData.padding.right - horizontalBar) /
                    scale,
              );

              final mappedInsets = EdgeInsets.only(
                top:
                    math.max(0, outerData.viewInsets.top - verticalBar) / scale,
                bottom:
                    math.max(0, outerData.viewInsets.bottom - verticalBar) /
                    scale,
                left:
                    math.max(0, outerData.viewInsets.left - horizontalBar) /
                    scale,
                right:
                    math.max(0, outerData.viewInsets.right - horizontalBar) /
                    scale,
              );

              return Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: LayoutBaseline.targetWidth,
                    height: LayoutBaseline.targetHeight,
                    child: ClipRect(
                      child: MediaQuery(
                        data: outerData.copyWith(
                          size: const Size(
                            LayoutBaseline.targetWidth,
                            LayoutBaseline.targetHeight,
                          ),
                          padding: mappedPadding,
                          viewPadding: mappedPadding, // Use mapped padding here
                          viewInsets: mappedInsets,
                          textScaler: const TextScaler.linear(1.0),
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

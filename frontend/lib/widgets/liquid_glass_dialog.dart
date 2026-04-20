import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dreamhunter/core/theme/app_theme.dart';

/// A reusable, highly-customizable "Glassmorphism" dialog component.
/// This widget provides a blurred, semi-transparent background with a subtle border
/// and gradient, perfect for modern indie game UIs.
class LiquidGlassDialog extends StatelessWidget {
  /// The content to display inside the glass panel.
  final Widget child;

  /// Optional fixed width. If null, it will expand to fit parent/child.
  final double? width;

  /// Optional fixed height. If null, it will expand to fit parent/child.
  final double? height;

  /// The roundness of the corners. Defaults to 20.0.
  final double borderRadius;

  /// The intensity of the background blur. If null, uses [GlassTheme.blurSigma].
  final double? blurSigma;

  /// The internal padding for the content. Defaults to 20.0.
  final EdgeInsetsGeometry padding;

  /// Optional background color override.
  final Color? color;

  /// Optional border/glow color override.
  final Color? glowColor;

  const LiquidGlassDialog({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 20.0,
    this.blurSigma,
    this.padding = const EdgeInsets.all(20.0),
    this.color,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final glassTheme =
        Theme.of(context).extension<GlassTheme>() ?? const GlassTheme();
    final sigma = blurSigma ?? glassTheme.blurSigma;

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color:
                  color ??
                  Colors.white.withValues(alpha: glassTheme.baseOpacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: (glowColor ?? Colors.white).withValues(
                  alpha: glassTheme.borderAlpha,
                ),
                width: 1.5,
              ),
              gradient: color != null
                  ? null
                  : const LinearGradient(
                      colors: [
                        Color.fromRGBO(255, 255, 255, 0.15),
                        Color.fromRGBO(255, 255, 255, 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.1),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: DefaultTextStyle(
              style:
                  Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
              child: Material(color: Colors.transparent, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

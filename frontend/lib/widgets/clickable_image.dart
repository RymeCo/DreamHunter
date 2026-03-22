import 'package:flutter/material.dart';

/// A highly interactive, animated "Liquid Glass" button for indie game UIs.
/// Supports both image-based and text/widget-based content.
///
/// ### How to use:
/// ```dart
/// GlassButton(
///   onTap: () => print('Button Tapped!'),
///   child: Text('Play'),
///   glowColor: Colors.blueAccent,
/// )
/// ```
class GlassButton extends StatefulWidget {
  /// Path to the asset image. Optional if [child] is provided.
  final String? imagePath;

  /// Content to display inside the button. Optional if [imagePath] is provided.
  final Widget? child;

  /// Callback function when the button is tapped.
  final VoidCallback? onTap;

  /// Width of the button. Defaults to null (shrink wrap).
  final double? width;

  /// Height of the button. Defaults to null (shrink wrap).
  final double? height;

  /// Whether the button scales up slightly when hovered/pressed.
  final bool clickResponsiveness;

  /// The color of the glow effect.
  final Color glowColor;

  /// Whether the button is currently interactive.
  final bool isClickable;

  /// Internal padding.
  final EdgeInsetsGeometry padding;

  /// Corner roundness.
  final double borderRadius;

  const GlassButton({
    super.key,
    this.imagePath,
    this.child,
    this.onTap,
    this.width,
    this.height,
    this.clickResponsiveness = true,
    this.glowColor = Colors.white,
    this.isClickable = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = 12.0,
  }) : assert(imagePath != null || child != null, 'Either imagePath or child must be provided');

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _isHovering = false;
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isClickable && (_isHovering || _isTapped);

    return GestureDetector(
      onTapDown: widget.isClickable && widget.clickResponsiveness
          ? (_) => setState(() => _isTapped = true)
          : null,
      onTapUp: widget.isClickable && widget.clickResponsiveness
          ? (_) => setState(() => _isTapped = false)
          : null,
      onTapCancel: widget.isClickable && widget.clickResponsiveness
          ? () => setState(() => _isTapped = false)
          : null,
      onTap: widget.isClickable ? widget.onTap : null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: AnimatedScale(
          scale: (widget.clickResponsiveness && active) ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.width,
            height: widget.height,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: active 
                ? Colors.white.withValues(alpha: 0.2) 
                : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: active 
                  ? widget.glowColor.withValues(alpha: 0.5) 
                  : Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: widget.glowColor.withValues(alpha: 0.4),
                        blurRadius: 15.0,
                        spreadRadius: 1.0,
                      ),
                    ]
                  : [],
            ),
            child: widget.imagePath != null
                ? Image.asset(
                    widget.imagePath!,
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.contain,
                  )
                : Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Legacy wrapper for MakeItButton
class MakeItButton extends StatelessWidget {
  final String imagePath;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool clickResponsiveness;
  final bool onHoverGlow;
  final bool isClickable;

  const MakeItButton({
    super.key,
    required this.imagePath,
    this.onTap,
    this.width = 50,
    this.height = 50,
    this.clickResponsiveness = true,
    this.onHoverGlow = true,
    this.isClickable = true,
  });

  @override
  Widget build(BuildContext context) {
    return GlassButton(
      imagePath: imagePath,
      onTap: onTap,
      width: width,
      height: height,
      clickResponsiveness: clickResponsiveness,
      glowColor: Colors.white,
      isClickable: isClickable,
      padding: EdgeInsets.zero,
      borderRadius: 0, // Legacy buttons didn't have rounded containers
    );
  }
}

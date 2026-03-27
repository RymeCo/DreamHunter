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
  /// Path to the asset image. Optional if [child] or [label] is provided.
  final String? imagePath;

  /// Content to display inside the button. Optional if [imagePath] or [label] is provided.
  final Widget? child;

  /// Text to display inside the button. Shorthand for [child].
  final String? label;

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

  /// The background color override.
  final Color? color;

  /// The border color override.
  final Color? borderColor;

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
    this.label,
    this.onTap,
    this.width,
    this.height,
    this.clickResponsiveness = true,
    this.glowColor = Colors.white,
    this.color,
    this.borderColor,
    this.isClickable = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = 12.0,
  }) : assert(imagePath != null || child != null || label != null, 
          'Either imagePath, child, or label must be provided');

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _isHovering = false;
  bool _isTapped = false;

  void _updateTapped(bool tapped) {
    if (!mounted || _isTapped == tapped) return;
    setState(() => _isTapped = tapped);
  }

  void _updateHovering(bool hovering) {
    if (!mounted || _isHovering == hovering) return;
    setState(() => _isHovering = hovering);
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isClickable && (_isHovering || _isTapped);

    // Resolve Colors
    final Color baseBg = widget.color ?? Colors.white.withValues(alpha: 0.1);
    final Color activeBg = widget.color?.withValues(alpha: 0.2) ?? Colors.white.withValues(alpha: 0.2);
    
    final Color baseBorder = widget.borderColor ?? Colors.white.withValues(alpha: 0.2);
    final Color activeBorder = widget.borderColor?.withValues(alpha: 0.5) ?? widget.glowColor.withValues(alpha: 0.5);

    return GestureDetector(
      onTapDown: widget.isClickable && widget.clickResponsiveness
          ? (_) => _updateTapped(true)
          : null,
      onTapUp: widget.isClickable && widget.clickResponsiveness
          ? (_) => _updateTapped(false)
          : null,
      onTapCancel: widget.isClickable && widget.clickResponsiveness
          ? () => _updateTapped(false)
          : null,
      onTap: widget.isClickable ? widget.onTap : null,
      child: MouseRegion(
        onEnter: (_) => _updateHovering(true),
        onExit: (_) => _updateHovering(false),
        child: AnimatedScale(
          scale: (widget.clickResponsiveness && active) ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.width,
            height: widget.height,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: active ? activeBg : baseBg,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: active ? activeBorder : baseBorder,
                width: 1.5,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: (widget.borderColor ?? widget.glowColor).withValues(alpha: 0.4),
                        blurRadius: 15.0,
                        spreadRadius: 1.0,
                      ),
                    ]
                  : [],
            ),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.imagePath != null) {
      return Image.asset(
        widget.imagePath!,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.contain,
      );
    }
    
    if (widget.label != null) {
      return Center(
        child: Text(
          widget.label!,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Center(child: widget.child);
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
      borderRadius: 0, 
    );
  }
}

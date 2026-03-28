import 'package:flutter/material.dart';
import 'package:dreamhunter/services/audio_service.dart';

/// A highly interactive, animated "Liquid Glass" button for indie game UIs.
class GlassButton extends StatefulWidget {
  final String? imagePath;
  final Widget? child;
  final String? label;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final bool clickResponsiveness;
  final Color glowColor;
  final Color? color;
  final Color? borderColor;
  final bool isClickable;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool pulseEffect;
  final double pulseMinOpacity;

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
    this.pulseEffect = true,
    this.pulseMinOpacity = 0.4,
  }) : assert(imagePath != null || child != null || label != null, 
          'Either imagePath, child, or label must be provided');

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _isTapped = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: widget.pulseMinOpacity, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.pulseEffect) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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

    return MouseRegion(
      onEnter: (_) => _updateHovering(true),
      onExit: (_) => _updateHovering(false),
      child: GestureDetector(
        onTapDown: widget.isClickable && widget.clickResponsiveness ? (_) => _updateTapped(true) : null,
        onTapUp: widget.isClickable && widget.clickResponsiveness ? (_) => _updateTapped(false) : null,
        onTapCancel: widget.isClickable && widget.clickResponsiveness ? () => _updateTapped(false) : null,
        onTap: widget.isClickable ? () {
          AudioService().playClick();
          widget.onTap?.call();
        } : null,
        child: AnimatedScale(
          scale: (widget.clickResponsiveness && active) ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final pulse = widget.pulseEffect ? _pulseAnimation.value : 1.0;
              
              // Idle state: Subtle and pulsing
              // Active state: Brighter and more solid (snaps in/out)
              final double bgAlpha = active 
                ? 0.25 
                : (0.1 * pulse);
                
              final double borderAlpha = active
                ? 0.6
                : (0.2 * pulse);

              return Container(
                width: widget.width,
                height: widget.height,
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: (widget.color ?? Colors.white).withValues(alpha: bgAlpha),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: (active ? widget.glowColor : Colors.white).withValues(alpha: borderAlpha),
                    width: 1.5,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: (widget.borderColor ?? widget.glowColor).withValues(alpha: 0.5),
                            blurRadius: 18.0,
                            spreadRadius: 1.0,
                          ),
                        ]
                      : [],
                ),
                child: _buildContent(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.imagePath != null) {
      return Image.asset(
        widget.imagePath!,
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

    return widget.child ?? const SizedBox.shrink();
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
      pulseEffect: false,
    );
  }
}

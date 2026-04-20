import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/core/theme/app_theme.dart';

/// A highly interactive, animated "Liquid Glass" button for indie game UIs.
///
/// Features built-in:
/// - Context-aware Pulse animation (Stops when disabled)
/// - Scale animation (Click responsiveness)
/// - Theme-centric styling via GlassTheme extension
/// - Integrated Audio & Haptics
class GlassButton extends StatefulWidget {
  final String? imagePath;
  final Widget? child;
  final String? label;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final bool clickResponsiveness;
  final Color? glowColor;
  final Color? color;
  final Color? hoverColor;
  final Color? hoverTextColor;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final bool isClickable;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool pulseEffect;
  final double? pulseMinOpacity;
  final String? semanticLabel;

  const GlassButton({
    super.key,
    this.imagePath,
    this.child,
    this.label,
    this.onTap,
    this.width,
    this.height,
    this.clickResponsiveness = true,
    this.glowColor,
    this.color,
    this.hoverColor,
    this.hoverTextColor,
    this.borderColor,
    this.hoverBorderColor,
    this.isClickable = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = 12.0,
    this.pulseEffect = true,
    this.pulseMinOpacity,
    this.semanticLabel,
  }) : assert(
         imagePath != null || child != null || label != null,
         'Either imagePath, child, or label must be provided',
       );

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
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

    // Default static animation if no pulse
    _pulseAnimation = const AlwaysStoppedAnimation(1.0);

    if (widget.pulseEffect && widget.isClickable) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(GlassButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Logic Gap Fix: Handle dynamic changes to clickability or pulse settings
    if (widget.isClickable && widget.pulseEffect) {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.pulseEffect) {
      final glass = Theme.of(context).extension<GlassTheme>() ?? const GlassTheme();
      final min = widget.pulseMinOpacity ?? glass.pulseMinOpacity;
      
      _pulseAnimation = Tween<double>(begin: min, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isClickable) return;
    AudioManager.instance.playClick();
    HapticManager.instance.light();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<GlassTheme>() ?? const GlassTheme();
    final bool active = widget.isClickable && (_isHovering || _isTapped);
    final accent = widget.glowColor ?? Colors.white;

    return Semantics(
      label: widget.semanticLabel ?? widget.label ?? 'Button',
      button: true,
      enabled: widget.isClickable,
      child: MouseRegion(
        cursor: widget.isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTapDown: widget.isClickable && widget.clickResponsiveness ? (_) => setState(() => _isTapped = true) : null,
          onTapUp: widget.isClickable && widget.clickResponsiveness ? (_) => setState(() => _isTapped = false) : null,
          onTapCancel: () => setState(() => _isTapped = false),
          onTap: _handleTap,
          child: AnimatedScale(
            scale: active ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutBack,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final pulse = (widget.pulseEffect && widget.isClickable) ? _pulseAnimation.value : 1.0;
                
                // Theme-centric alpha calculations
                final double bgAlpha = active ? 0.25 : (glass.baseOpacity * pulse);
                final double borderAlpha = active ? 0.6 : (glass.borderAlpha * pulse);

                return Container(
                  width: widget.width,
                  height: widget.height,
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    color: (active ? (widget.hoverColor ?? widget.color ?? accent) : (widget.color ?? Colors.white))
                        .withValues(alpha: bgAlpha),
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    border: Border.all(
                      color: (active ? (widget.hoverBorderColor ?? accent) : (widget.borderColor ?? Colors.white))
                          .withValues(alpha: borderAlpha),
                      width: 1.5,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.5),
                              blurRadius: 18.0,
                              spreadRadius: 1.0,
                            ),
                          ]
                        : [],
                  ),
                  child: _buildContent(active),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool active) {
    if (widget.imagePath != null) {
      return Image.asset(widget.imagePath!, fit: BoxFit.contain);
    }

    if (widget.label != null) {
      return Center(
        child: Text(
          widget.label!.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: active ? (widget.hoverTextColor ?? Colors.white) : Colors.white,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
      );
    }

    return Center(child: widget.child ?? const SizedBox.shrink());
  }
}

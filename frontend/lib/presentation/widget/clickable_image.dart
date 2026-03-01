import 'package:flutter/material.dart';

class MakeItButton extends StatefulWidget {
  final String imagePath;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool clickResponsiveness; // New property
  final bool onHoverGlow; // New property
  final bool isClickable; // New property

  const MakeItButton({
    super.key,
    required this.imagePath,
    this.onTap,
    this.width = 50,
    this.height = 50,
    this.clickResponsiveness = true, // Default to true
    this.onHoverGlow = true, // Default to true
    this.isClickable = true, // Default to true
  });

  @override
  State<MakeItButton> createState() => _MakeItButtonState();
}

class _MakeItButtonState extends State<MakeItButton> {
  bool _isHovering = false;
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
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
          scale: (widget.clickResponsiveness && (_isHovering || _isTapped))
              ? 1.1
              : 1.0,
          duration: const Duration(
            milliseconds: 100,
          ), // Reduced duration for responsiveness
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 100,
            ), // Reduced duration for responsiveness
            decoration: widget.onHoverGlow && (_isHovering || _isTapped)
                ? BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withAlpha(
                          (255 * 0.8).round(),
                        ), // White glow color
                        blurRadius:
                            25.0, // Increased blur for a softer, more spread effect
                        spreadRadius:
                            1.0, // Reduced spread to keep it closer to the edges
                        offset: Offset.zero, // Ensure the shadow is centered
                      ),
                    ],
                  )
                : null,
            child: Image.asset(
              widget.imagePath,
              width: widget.width,
              height: widget.height,
            ),
          ),
        ),
      ),
    );
  }
}

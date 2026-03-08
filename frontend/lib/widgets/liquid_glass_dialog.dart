import 'package:flutter/material.dart';

class LiquidGlassDialog extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;

  const LiquidGlassDialog({
    super.key,
    required this.child,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }
}

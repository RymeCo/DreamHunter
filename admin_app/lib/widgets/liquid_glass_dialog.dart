import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable, highly-customizable "Glassmorphism" dialog component.
/// This widget provides a blurred, semi-transparent background with a subtle border
/// and gradient, perfect for modern indie game UIs.
///
/// ### How to use:
/// ```dart
/// LiquidGlassDialog(
///   width: 300,
///   height: 400,
///   borderRadius: 15.0, // Optional
///   blurSigma: 10.0,    // Optional
///   padding: EdgeInsets.all(16), // Optional
///   child: MyContentWidget(),
/// )
/// ```
class LiquidGlassDialog extends StatelessWidget {
  /// The content to display inside the glass panel.
  final Widget child;

  /// Optional fixed width. If null, it will expand to fit parent/child.
  final double? width;

  /// Optional fixed height. If null, it will expand to fit parent/child.
  final double? height;

  /// The roundness of the corners. Defaults to 20.0.
  final double borderRadius;

  /// The intensity of the background blur. Defaults to 8.0.
  final double blurSigma;

  /// The internal padding for the content. Defaults to 20.0.
  final EdgeInsetsGeometry padding;

  const LiquidGlassDialog({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 20.0,
    this.blurSigma = 8.0,
    this.padding = const EdgeInsets.all(20.0),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.1),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.2),
                width: 1.5,
              ),
              gradient: const LinearGradient(
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
            child: Material(color: Colors.transparent, child: child),
          ),
        ),
      ),
    );
  }
}

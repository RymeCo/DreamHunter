import 'package:flutter/material.dart';

/// The official DreamHunter logo, standardizing branding across the app.
class AppLogo extends StatelessWidget {
  final double size;
  final bool animated;

  const AppLogo({super.key, this.size = 180, this.animated = true});

  @override
  Widget build(BuildContext context) {
    // Note: Future expansion could wrap this in a TweenAnimationBuilder for 'animated' flag
    return Hero(
      tag: 'app_logo',
      child: Image.asset(
        'assets/images/dashboard/core/splash_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

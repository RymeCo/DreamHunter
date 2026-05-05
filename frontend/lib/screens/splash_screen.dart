import 'package:dreamhunter/widgets/branding/app_logo.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/screens/dashboard_screen.dart';
import 'package:dreamhunter/services/loading/app_loader.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    // Start loading as soon as the first frame is painted
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeAppData());
  }

  Future<void> _initializeAppData() async {
    // 1. Perform REAL asset precaching
    await AppLoader.precacheAll(context, (progress) {
      if (mounted) {
        setState(() => _progress = progress);
      }
    });

    // 2. Tiny grace period for visual smoothness
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _progress = 1.0);

    // 3. Smooth fade transition to Dashboard
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DashboardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Dynamic Background
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 1.0),
              child: Image.asset(
                'assets/images/dashboard/background_1.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Responsive Logo
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: AppLogo(size: screenWidth * 0.85),
            ),
          ),
          // Minimalist Loading Bar
          Positioned(
            bottom: 60,
            left: 50,
            right: 50,
            child: GameLoadingBar(progress: _progress),
          ),
        ],
      ),
    );
  }
}

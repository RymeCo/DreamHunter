import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/game_widgets.dart';
import 'package:dreamhunter/screens/dashboard_screen.dart';
import 'package:dreamhunter/services/pre_loader.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppData();
    });
  }

  Future<void> _initializeAppData() async {
    final startTime = DateTime.now();

    await PreLoader.precacheAll(context, (progress) {
      if (mounted) {
        setState(() => _progress = progress);
      }
    });

    final endTime = DateTime.now();
    final elapsed = endTime.difference(startTime).inMilliseconds;
    const minimumWait = 2000;

    if (elapsed < minimumWait) {
      final remaining = minimumWait - elapsed;
      final steps = 20;
      final baseProgress = PreLoader.totalCount / (PreLoader.totalCount + 1);
      final remainingProgress = 1 / (PreLoader.totalCount + 1);

      for (int i = 1; i <= steps; i++) {
        await Future.delayed(Duration(milliseconds: remaining ~/ steps));
        if (!mounted) return;
        setState(() {
          _progress = baseProgress + (i / steps) * remainingProgress;
        });
      }
    }

    if (!mounted) return;
    setState(() => _progress = 1.0);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background with blur
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 1.0),
              child: Image.asset(
                'assets/images/dashboard/background_1.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Centered Logo and Loading
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: 0,
            right: 0,
            child: const AppLogo(size: 550),
          ),
          Positioned(
            bottom: 40,
            left: 40,
            right: 40,
            child: GameLoadingBar(progress: _progress),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/loading_screen.dart';
import 'package:dreamhunter/screens/dashboard_screen.dart';

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
    // Use addPostFrameCallback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppData();
    });
  }

  Future<void> _initializeAppData() async {
    final startTime = DateTime.now();

    final imagesToPrecache = [
      'assets/images/dashboard/main_background.png',
      'assets/images/dashboard/background_1.png',
      'assets/images/dashboard/shop_stall.png',
      'assets/images/dashboard/roulette_man.png',
      'assets/images/dashboard/signage.png',
      'assets/images/game/environment/dorm.png',
    ];

    // Pre-cache images in parallel and update progress
    int loadedCount = 0;
    await Future.wait(imagesToPrecache.map((path) async {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (e) {
        debugPrint('Failed to precache: $path - $e');
      } finally {
        if (mounted) {
          loadedCount++;
          setState(() {
            _progress = (loadedCount) / (imagesToPrecache.length + 1);
          });
        }
      }
    }));

    // Ensure we wait at least 2 seconds total for the logo display
    final endTime = DateTime.now();
    final elapsed = endTime.difference(startTime).inMilliseconds;
    const minimumWait = 2000;

    if (elapsed < minimumWait) {
      final remaining = minimumWait - elapsed;
      // Increment progress smoothly during the remaining wait
      final steps = 20;
      for (int i = 1; i <= steps; i++) {
        await Future.delayed(Duration(milliseconds: remaining ~/ steps));
        if (!mounted) return;
        setState(() {
          _progress = (imagesToPrecache.length / (imagesToPrecache.length + 1)) +
              ((i / steps) * (1 / (imagesToPrecache.length + 1)));
        });
      }
    }

    if (!mounted) return;

    setState(() {
      _progress = 1.0;
    });

    // Short delay at 100% for smooth transition
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // Transition to Dashboard
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 1.0),
            child: Image.asset(
              'assets/images/dashboard/background_1.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Positioned(
            top: 50.0,
            left: 0,
            right: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                  child: Image.asset(
                    'assets/images/core/splash_logo.png',
                    width: 600.0,
                    height: 600.0,
                    color: const Color.fromRGBO(169, 13, 200, 0.5),
                    colorBlendMode: BlendMode.srcATop,
                  ),
                ),
                Image.asset(
                  'assets/images/core/splash_logo.png',
                  width: 600.0,
                  height: 600.0,
                  color: const Color.fromRGBO(228, 159, 240, 0.8),
                  colorBlendMode: BlendMode.modulate,
                ),
              ],
            ),
          ),
          LoadingScreen(progress: _progress),
        ],
      ),
    );
  }
}

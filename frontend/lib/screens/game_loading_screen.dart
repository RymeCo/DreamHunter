import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/game_widgets.dart';
import 'package:dreamhunter/services/game_pre_loader.dart';
import 'package:dreamhunter/screens/game_screen.dart';

class GameLoadingScreen extends StatefulWidget {
  const GameLoadingScreen({super.key});

  @override
  State<GameLoadingScreen> createState() => _GameLoadingScreenState();
}

class _GameLoadingScreenState extends State<GameLoadingScreen> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPreloading();
    });
  }

  Future<void> _startPreloading() async {
    final startTime = DateTime.now();

    await GamePreLoader.preload((progress) {
      if (mounted) {
        setState(() => _progress = progress);
      }
    });

    final endTime = DateTime.now();
    final elapsed = endTime.difference(startTime).inMilliseconds;
    const minimumWait = 1500;

    if (elapsed < minimumWait) {
      final remaining = minimumWait - elapsed;
      await Future.delayed(Duration(milliseconds: remaining));
    }

    if (!mounted) return;
    setState(() => _progress = 1.0);
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GameScreen(),
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
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 1.0),
              child: Image.asset(
                'assets/images/dashboard/background_1.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ENTERING THE DREAM...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                GameLoadingBar(progress: _progress),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

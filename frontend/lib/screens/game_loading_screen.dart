import 'package:dreamhunter/widgets/branding/app_logo.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/services/loading/game_loader.dart';
import 'package:dreamhunter/screens/game_screen.dart';

class GameLoadingScreen extends StatefulWidget {
  final String characterType;
  const GameLoadingScreen({super.key, required this.characterType});

  @override
  State<GameLoadingScreen> createState() => _GameLoadingScreenState();
}

class _GameLoadingScreenState extends State<GameLoadingScreen> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPreloading());
  }

  Future<void> _startPreloading() async {
    debugPrint('GameLoadingScreen: Starting preloading sequence');
    // 1. REAL ASSET LOADING
    await GameLoader.loadGameAssets((progress) {
      if (mounted) {
        setState(() => _progress = progress);
      }
    });

    // 2. Final state and brief smooth delay
    if (!mounted) return;
    debugPrint('GameLoadingScreen: Assets loaded, final delay');
    setState(() => _progress = 1.0);
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    // 3. Transition to Game
    debugPrint('GameLoadingScreen: Transitioning to GameScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Theme-synced Background
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 1.0),
              child: Image.asset(
                'assets/images/dashboard/background_1.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Responsive Branding
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120),
              child: AppLogo(size: screenWidth * 0.8),
            ),
          ),
          // Clean Loading Info
          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ENTERING THE DREAM...',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 3,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                GameLoadingBar(progress: _progress),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

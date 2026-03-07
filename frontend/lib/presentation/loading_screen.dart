import 'dart:async';
import 'package:dreamhunter/presentation/game_screen.dart';
import 'package:flame/flame.dart';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart' hide Text;
import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  double _progress = 0.0;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _startPreloading();
  }

  Future<void> _startPreloading() async {
    // Set prefix to empty since our assets are in assets/ (not assets/images/)
    Flame.images.prefix = '';
    
    // 1. Load basic images
    setState(() => _progress = 0.2);
    await Flame.images.loadAll([
      'sprites/character/char1.png',
      'widget/smallcirclefigure.png',
    ]);

    // 2. Load Tiled map
    setState(() => _progress = 0.6);
    await TiledComponent.load('map_1.json', Vector2.all(32));

    // 3. Finalize
    setState(() => _progress = 1.0);
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GameScreen()),
      );
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotationTransition(
              turns: _rotationController,
              child: Image.asset('assets/widget/smallcirclefigure.png', width: 80, height: 80),
            ),
            const SizedBox(height: 40),
            Container(
              width: 250,
              height: 10,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.purpleAccent, width: 2),
                borderRadius: BorderRadius.circular(5),
              ),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "PREPARING DREAM WORLD... ${(_progress * 100).toInt()}%",
              style: const TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

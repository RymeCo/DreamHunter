import 'package:flutter/material.dart';
import 'dart:async';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  // Added TickerProviderStateMixin
  double _progress = 0.0;
  Timer? _timer;
  late AnimationController
  _rotationController; // Animation controller for rotation

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {
        if (_progress < 1.0) {
          _progress += 0.01;
        } else {
          _timer?.cancel();
        }
      });
    });

    _rotationController = AnimationController(
      duration: const Duration(seconds: 3), // Rotate over 3 seconds
      vsync: this,
    )..repeat(); // Repeat the animation
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rotationController.dispose(); // Dispose of the animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Make Scaffold transparent
      extendBodyBehindAppBar: true, // Allow content to extend behind app bar
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Row(
          // Row is now direct child of Align
          mainAxisAlignment: MainAxisAlignment
              .spaceBetween, // Distribute elements across the width
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle, // Added this line
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(
                      255,
                      229,
                      46,
                      246,
                    ).withAlpha((255 * 0.5).round()),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: RotationTransition(
                turns: _rotationController,
                child: Image.asset(
                  'assets/widget/smallcirclefigure.png',
                  width: 48, // 2x larger
                  height: 48, // 2x larger
                ),
              ),
            ),
            // Removed SizedBox here, as Expanded and SpaceBetween will handle spacing
            Expanded(
              // Loading Bar (middle)
              child: Container(
                height: 28.0,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black,
                    width: 3.0,
                  ), // Added black border
                ),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 20.0,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(255, 203, 28, 197),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(_progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 18,
                color: const Color.fromARGB(255, 188, 173, 173),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

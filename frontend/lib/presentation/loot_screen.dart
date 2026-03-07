import 'package:dreamhunter/domain/game/playground_service.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

class LootScreen extends StatelessWidget {
  const LootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PlaygroundService();
    
    return Scaffold(
      body: Stack(
        children: [
          // Background (could be a dimmed version of the game or a static image)
          Image.asset(
            'assets/widget/mainbg.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
          Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "DREAM CLEAR!",
                    style: TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 20),
                  const Text("LOOT COLLECTED", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/widget/smallcirclefigure.png', width: 30),
                      const SizedBox(width: 10),
                      const Text(
                        "+150 Essence",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      service.onWin(); // Increment Ante level
                      Navigator.pop(context); // Go back to Dashboard
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text(
                      "ANTE UP!",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("RETURN TO CITY", style: TextStyle(color: Colors.white54)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

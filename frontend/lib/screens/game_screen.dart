import 'package:flutter/material.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          "Dream World Loading...",
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}

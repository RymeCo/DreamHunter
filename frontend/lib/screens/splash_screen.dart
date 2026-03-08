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
  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
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
            imageFilter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 5.0),
            child: Image.asset(
              'assets/widget/bg1.png',
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
                  imageFilter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Image.asset(
                    'assets/widget/splashlogo.png',
                    width: 600.0,
                    height: 600.0,
                    color: const Color.fromRGBO(169, 13, 200, 0.5),
                    colorBlendMode: BlendMode.srcATop,
                  ),
                ),
                Image.asset(
                  'assets/widget/splashlogo.png',
                  width: 600.0,
                  height: 600.0,
                  color: const Color.fromRGBO(228, 159, 240, 0.8),
                  colorBlendMode: BlendMode.modulate,
                ),
              ],
            ),
          ),
          const LoadingScreen(),
        ],
      ),
    );
  }
}

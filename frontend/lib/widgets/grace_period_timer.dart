import 'dart:async';
import 'package:flutter/material.dart';

class GracePeriodTimer extends StatefulWidget {
  final VoidCallback onFinished;

  const GracePeriodTimer({super.key, required this.onFinished});

  @override
  State<GracePeriodTimer> createState() => _GracePeriodTimerState();
}

class _GracePeriodTimerState extends State<GracePeriodTimer> with SingleTickerProviderStateMixin {
  int _secondsRemaining = 10;
  Timer? _timer;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _startTimer();
  }

  void _startTimer() {
    _controller.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
          _controller.reset();
          _controller.forward();
        });
      } else {
        _timer?.cancel();
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Text(
          '$_secondsRemaining',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 120,
            fontWeight: FontWeight.w900,
            letterSpacing: -5,
            shadows: [
              Shadow(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.5),
                blurRadius: 30,
              ),
              const Shadow(
                color: Colors.black45,
                offset: Offset(4, 4),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

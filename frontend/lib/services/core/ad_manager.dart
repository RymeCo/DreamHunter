import 'package:flutter/material.dart';
import 'package:dreamhunter/services/game/match_manager.dart';

/// A centralized service to handle advertisements.
/// 
/// Currently acts as a "Simulator" but designed to be easily swapped
/// with a real Ad SDK (like AdMob or Unity Ads) in the future.
class AdManager {
  static final AdManager instance = AdManager._internal();
  AdManager._internal();

  /// Shows a rewarded ad and executes [onRewardEarned] if the user completes it.
  /// 
  /// This abstraction is crucial: when we integrate a real SDK, we only 
  /// change the logic here, and all buttons in the app will work automatically.
  Future<void> showRewardAd({
    required BuildContext context,
    required VoidCallback onRewardEarned,
  }) async {
    // 1. Auto-pause the game to prevent monsters from attacking during the ad
    MatchManager.instance.pauseGame();

    // 2. Show the Simulator Overlay
    final bool? success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _AdSimulatorOverlay(),
    );

    // 3. If the user finished (or the simulator succeeded), grant reward
    if (success == true) {
      onRewardEarned();
    }

    // 4. Auto-resume the game
    MatchManager.instance.resumeGame();
  }
}

/// Internal UI for the Ad Simulator.
/// This will be replaced by the SDK's full-screen overlay later.
class _AdSimulatorOverlay extends StatefulWidget {
  const _AdSimulatorOverlay();

  @override
  State<_AdSimulatorOverlay> createState() => _AdSimulatorOverlayState();
}

class _AdSimulatorOverlayState extends State<_AdSimulatorOverlay> {
  int _secondsRemaining = 5; // Increased to 5s for a more "ad-like" feel

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() async {
    while (_secondsRemaining > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _secondsRemaining--;
      });
    }

    if (mounted) {
      Navigator.pop(context, true); // Success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.amberAccent.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_circle_fill,
              color: Colors.amberAccent,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              'WATCHING AD...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    decoration: TextDecoration.none,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reward in $_secondsRemaining s',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                    decoration: TextDecoration.none,
                  ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/widgets/game/pause_dialog.dart';
import 'package:dreamhunter/widgets/game/vignette_overlay.dart';
import 'package:dreamhunter/widgets/game/grace_timer_overlay.dart';
import 'package:dreamhunter/widgets/game/match_timer_overlay.dart';
import 'package:dreamhunter/widgets/game/game_economy_hud.dart';
import 'package:dreamhunter/widgets/game/tutorial_hud.dart';
import 'package:dreamhunter/services/progression/tutorial_service.dart';
import 'package:dreamhunter/widgets/game/reward_dialog.dart';
import 'package:dreamhunter/services/loading/game_loader.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final DreamHunterGame _game;
  final MatchManager _matchManager = MatchManager.instance;
  bool _rewardDialogShown = false;

  @override
  void initState() {
    super.initState();

    // Reset economy and pause state for a new match
    _matchManager.resetMatch();

    // Reset tutorial to start if not already fully completed
    TutorialService.instance.resetProgressIfNotCompleted();

    _game = DreamHunterGame(
      onMatchEnded: () {
        _showRewardDialog();
      },
    );
    // Sync Flame engine with Singleton state
    _game.paused = _matchManager.isPaused;
    _matchManager.addListener(_onMatchStateChanged);

    // Apply 10% volume boost for game immersion
    AudioManager.instance.setGameMode(true);
  }

  @override
  void dispose() {
    _matchManager.removeListener(_onMatchStateChanged);
    // Ensure game state is clean for next run
    _matchManager.resumeGame();
    // Memory Management: Clear Flame image cache
    GameLoader.unloadGameAssets();
    // Restore normal volume level
    AudioManager.instance.setGameMode(false);
    super.dispose();
  }

  void _onMatchStateChanged() {
    if (mounted) {
      // 1. Victory Check
      if (_matchManager.isGameWon && !_rewardDialogShown) {
        _showRewardDialog();
        return;
      }

      // 2. Match Ended Check (Loss or Forfeit)
      if (_matchManager.matchEnded &&
          !_rewardDialogShown &&
          !_matchManager.isForfeited) {
        _showRewardDialog();
        return;
      }

      // 3. Pause Check
      if (_game.paused != _matchManager.isPaused) {
        setState(() {
          _game.paused = _matchManager.isPaused;
        });
      }
    }
  }

  Future<void> _showPauseDialog() async {
    _matchManager.pauseGame();

    final result = await showGeneralDialog(
      context: context,
      barrierLabel: "PauseDialog",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: const PauseDialog()),
        );
      },
    );

    if (result == 'quit') {
      _matchManager.setForfeited();
      // Bypassing Reward Screen as per user request
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      // Resume when dialog is dismissed normally
      _matchManager.resumeGame();
    }
  }

  Future<void> _showRewardDialog() async {
    if (_rewardDialogShown) return;
    _rewardDialogShown = true;

    _matchManager.pauseGame();

    if (!mounted) return;

    await showGeneralDialog(
      context: context,
      barrierLabel: "RewardDialog",
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: const RewardDialog(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // dispose() handles asset unloading, so we just allow the pop.
      },
      child: Scaffold(
        body: Stack(
          children: [
            // The Game
            Positioned.fill(child: GameWidget(game: _game)),

            // Atmosphere Overlay
            Positioned.fill(child: const VignetteOverlay()),

            // Economy HUD
            Positioned(top: 45, left: 20, child: GameEconomyHUD(game: _game)),

            // Tutorial HUD
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: TutorialHUD(game: _game),
            ),

            // Grace Timer Overlay
            Positioned(
              top: 150,
              left: 0,
              right: 0,
              child: GraceTimerOverlay(notifier: _game.graceTimer),
            ),

            // Match Timer Overlay
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: MatchTimerOverlay(
                  matchNotifier: _game.stopwatch,
                  graceNotifier: _game.graceTimer,
                ),
              ),
            ),

            // Pause Button Overlay
            Positioned(
              top: 40,
              right: 20,
              child: ListenableBuilder(
                listenable: _matchManager,
                builder: (context, child) {
                  return GlassButton(
                    width: 50,
                    height: 50,
                    padding: EdgeInsets.zero,
                    borderRadius: 25,
                    onTap: _showPauseDialog,
                    child: Icon(
                      _matchManager.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

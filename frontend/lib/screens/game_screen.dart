import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/haunted_dorm_game.dart';
import '../game/core/game_state_manager.dart';
import '../widgets/game_economy_hud.dart';
import '../widgets/build_menu.dart';
import '../widgets/upgrade_menu.dart';
import '../widgets/pause_menu_overlay.dart';
import '../widgets/clickable_image.dart';
import '../widgets/liquid_glass_dialog.dart';

class GameScreen extends StatefulWidget {
  final String characterType;
  const GameScreen({super.key, required this.characterType});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late HauntedDormGame _game;

  @override
  void initState() {
    super.initState();
    _game = HauntedDormGame(characterType: widget.characterType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GameWidget(
            game: _game,
            overlayBuilderMap: {
              'BuildMenu': (context, HauntedDormGame game) => BuildMenu(game: game),
              'UpgradeMenu': (context, HauntedDormGame game) => UpgradeMenu(game: game),
              'PauseMenu': (context, HauntedDormGame game) => PauseMenuOverlay(game: game),
              'GameOver': (context, HauntedDormGame game) => Center(
                child: LiquidGlassDialog(
                  width: 320,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'GAME OVER',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GlassButton(
                        label: 'BACK TO DASHBOARD',
                        onTap: () => Navigator.of(context).pop(),
                        glowColor: Colors.redAccent,
                      ),
                    ],
                  ),
                ),
              ),
            },
          ),
          
          // TOP HUD BAR
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // CENTER TIMER
                  ListenableBuilder(
                    listenable: _game.gameState,
                    builder: (context, _) {
                      final isGrace = _game.gameState.status == GameStatus.grace;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LiquidGlassDialog(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            borderRadius: 12,
                            glowColor: isGrace ? Colors.redAccent : Colors.amberAccent,
                            child: Text(
                              _game.gameState.formattedTime,
                              style: TextStyle(
                                color: isGrace ? Colors.redAccent : Colors.amberAccent,
                                fontSize: 32, // Larger
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isGrace ? 'GRACE PERIOD' : 'TIME REMAINING',
                            style: TextStyle(
                              color: isGrace ? Colors.redAccent : Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // TOP RIGHT PAUSE
                  Align(
                    alignment: Alignment.centerRight,
                    child: GlassButton(
                      width: 56, // Scaled up
                      height: 56,
                      borderRadius: 14,
                      glowColor: Colors.white,
                      onTap: () {
                        if (!_game.overlays.isActive('PauseMenu')) {
                          _game.pauseEngine();
                          _game.overlays.add('PauseMenu');
                        }
                      },
                      child: const Icon(Icons.pause_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // ECONOMY HUD (Left side)
          GameEconomyHUD(game: _game),

          // GIANT GRACE COUNTDOWN
          IgnorePointer(
            child: Center(
              child: ListenableBuilder(
                listenable: _game.gameState,
                builder: (context, _) {
                  final isGrace = _game.gameState.status == GameStatus.grace;
                  final graceSeconds = _game.gameState.graceTimeRemaining.ceil();

                  // Brief "GO!" flash when grace ends
                  final showGo = !isGrace &&
                      _game.gameState.matchTimeRemaining >
                          (HauntedDormGame.matchDuration - 1.5);

                  if (!isGrace && !showGo) return const SizedBox.shrink();

                  return TweenAnimationBuilder<double>(
                    key: ValueKey(graceSeconds),
                    duration: const Duration(milliseconds: 300),
                    tween: Tween(begin: 1.5, end: 1.0),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Text(
                          showGo ? 'GO!' : '$graceSeconds',
                          style: TextStyle(
                            color: showGo ? Colors.greenAccent : Colors.white,
                            fontSize: 120,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            shadows: [
                              Shadow(
                                color: (showGo
                                        ? Colors.greenAccent
                                        : Colors.white)
                                    .withValues(alpha: 0.5),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

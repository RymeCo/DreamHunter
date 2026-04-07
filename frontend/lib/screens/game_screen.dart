import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/haunted_dorm_game.dart';
import 'package:dreamhunter/widgets/pause_menu_overlay.dart';
import 'package:dreamhunter/widgets/grace_period_timer.dart';
import 'package:dreamhunter/widgets/clickable_image.dart';
import 'package:dreamhunter/widgets/game_economy_hud.dart';
import 'package:dreamhunter/widgets/build_menu.dart';
import 'package:dreamhunter/widgets/upgrade_menu.dart';
import 'package:dreamhunter/services/game_pre_loader.dart';
import 'package:dreamhunter/services/audio_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final HauntedDormGame _game;

  @override
  void initState() {
    super.initState();
    AudioService().playInGameMusic();
    _game = HauntedDormGame(characterType: 'max');
  }

  @override
  void dispose() {
    GamePreLoader.unloadGameAssets();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(
        children: [
          GameWidget(
            game: _game,
            overlayBuilderMap: {
              'PauseMenu': (context, HauntedDormGame game) =>
                  PauseMenuOverlay(game: game),
              'EconomyHUD': (context, HauntedDormGame game) =>
                  GameEconomyHUD(game: game),
              'GraceTimer': (context, HauntedDormGame game) => GracePeriodTimer(
                onFinished: () {
                  game.overlays.remove('GraceTimer');
                  game.isGracePeriod = false;
                },
              ),
              'BuildMenu': (context, HauntedDormGame game) => 
                  BuildMenu(game: game),
              'UpgradeMenu': (context, HauntedDormGame game) =>
                  UpgradeMenu(game: game),
            },
            loadingBuilder: (context) => const Center(
              child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
            ),
            initialActiveOverlays: const ['EconomyHUD'],
          ),
          Positioned(
            top: 40,
            right: 20,
            child: GlassButton(
              label: 'II',
              width: 50,
              height: 50,
              borderRadius: 12,
              glowColor: Colors.white70,
              pulseMinOpacity: 0.6,
              onTap: () {
                if (!_game.overlays.isActive('PauseMenu')) {
                  _game.pauseEngine();
                  _game.overlays.add('PauseMenu');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

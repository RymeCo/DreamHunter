import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/screens/game_loading_screen.dart';

class MatchmakingDialog extends StatefulWidget {
  const MatchmakingDialog({super.key});

  @override
  State<MatchmakingDialog> createState() => _MatchmakingDialogState();
}

class _MatchmakingDialogState extends State<MatchmakingDialog> {
  final List<String> _skins = ['nun', 'max', 'jack'];
  final List<String> _aiNames = [
    'ShadowHunter',
    'Dreamer99',
    'NightOwl',
    'SleepyHead',
    'GhostBuster',
    'DarkKnight',
    'Moonlight',
    'StarGazer',
  ];

  late String _playerSkin;
  int _playerSkinIndex = 1;
  bool _isReady = false;

  // All 8 slots
  final List<Map<String, String>?> _slots = List.generate(8, (_) => null);
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _playerSkin = _skins[_playerSkinIndex];
    // YOU are NOT in slot 0 yet
    _startMatchmaking();
  }

  void _startMatchmaking() {
    _fillNextAISlot();
  }

  void _fillNextAISlot() {
    if (!mounted) return;

    List<int> emptyAISlots = [];
    for (int i = 1; i < 8; i++) {
      if (_slots[i] == null) emptyAISlots.add(i);
    }

    if (emptyAISlots.isNotEmpty) {
      int slotIndex = emptyAISlots[_random.nextInt(emptyAISlots.length)];
      setState(() {
        _slots[slotIndex] = {
          'name': _aiNames[_random.nextInt(_aiNames.length)],
          'skin': _skins[_random.nextInt(_skins.length)],
        };
      });

      // Schedule next AI join with random delay 1ms to 250ms
      final delay = _random.nextInt(250) + 1;
      Future.delayed(Duration(milliseconds: delay), _fillNextAISlot);
    } else {
      // All AI slots full, check if we can start
      _checkTransition();
    }
  }

  void _checkTransition() {
    bool allAIFull = true;
    for (int i = 1; i < 8; i++) {
      if (_slots[i] == null) {
        allAIFull = false;
        break;
      }
    }

    if (allAIFull && _isReady) {
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => GameLoadingScreen(characterType: _playerSkin),
          ),
        );
      });
    }
  }

  void _toggleReady() {
    setState(() {
      _isReady = true;
      _slots[0] = {'name': 'YOU', 'skin': _playerSkin};
    });
    _checkTransition();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _cyclePlayerSkin() {
    setState(() {
      _playerSkinIndex = (_playerSkinIndex + 1) % _skins.length;
      _playerSkin = _skins[_playerSkinIndex];
      // If already ready, update slot 0 immediately
      if (_isReady) {
        _slots[0] = {'name': 'YOU', 'skin': _playerSkin};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int joinedCount = _slots.where((s) => s != null).length;

    return Center(
      child: LiquidGlassDialog(
        width: 380,
        height: 680,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const Text(
              'HAUNTED LOBBY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 16),

            // PREVIEW SELECTOR (Slightly smaller to fit)
            GestureDetector(
              onTap: _cyclePlayerSkin,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amberAccent, width: 2),
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  Image.asset(
                    'assets/images/game/characters/${_playerSkin}_front-32x48.png',
                    height: 130,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'TAP TO CHANGE SKIN',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'PLAYERS: $joinedCount / 8',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),

            // THE GRID: All 8 Players (Fixed Wrap - No Scroll)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(8, (index) {
                final slot = _slots[index];
                final isPlayerSlot = index == 0;

                return Container(
                  width: 70,
                  height: 90,
                  decoration: BoxDecoration(
                    color: isPlayerSlot && _isReady
                        ? Colors.amberAccent.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isPlayerSlot && _isReady
                          ? Colors.amberAccent
                          : Colors.white10,
                      width: isPlayerSlot && _isReady ? 2 : 1,
                    ),
                  ),
                  child: slot == null
                      ? Center(
                          child: isPlayerSlot
                              ? const Icon(
                                  Icons.lock_outline,
                                  color: Colors.white10,
                                  size: 18,
                                )
                              : const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white24,
                                  ),
                                ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/game/characters/${slot['skin']}_front-32x48.png',
                              height: 40,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              slot['name']!,
                              style: TextStyle(
                                color: isPlayerSlot
                                    ? Colors.amberAccent
                                    : Colors.white54,
                                fontSize: 8,
                                fontWeight: isPlayerSlot
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                );
              }),
            ),

            const Spacer(),
            // READY BUTTON
            if (!_isReady)
              GlassButton(
                label: 'READY',
                width: 200,
                height: 54,
                onTap: _toggleReady,
                glowColor: Colors.amberAccent,
              )
            else
              const GlassButton(
                label: 'WAITING...',
                width: 200,
                height: 54,
                glowColor: Colors.white24,
                pulseMinOpacity: 0.1,
              ),

            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white24, letterSpacing: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

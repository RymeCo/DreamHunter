import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'liquid_glass_dialog.dart';
import '../screens/game_loading_screen.dart';

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

  // All 8 slots
  final List<Map<String, String>?> _slots = List.generate(8, (_) => null);
  final Random _random = Random();
  Timer? _joinTimer;

  @override
  void initState() {
    super.initState();
    _playerSkin = _skins[_playerSkinIndex];
    // YOU are always in slot 0
    _slots[0] = {'name': 'YOU', 'skin': _playerSkin};
    _startMatchmaking();
  }

  void _startMatchmaking() {
    _joinTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;

      List<int> emptySlots = [];
      for (int i = 1; i < 8; i++) {
        if (_slots[i] == null) emptySlots.add(i);
      }

      if (emptySlots.isEmpty) {
        timer.cancel();
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  GameLoadingScreen(characterType: _playerSkin),
            ),
          );
        });
        return;
      }

      int slotIndex = emptySlots[_random.nextInt(emptySlots.length)];
      setState(() {
        _slots[slotIndex] = {
          'name': _aiNames[_random.nextInt(_aiNames.length)],
          'skin': _skins[_random.nextInt(_skins.length)],
        };
      });
    });
  }

  @override
  void dispose() {
    _joinTimer?.cancel();
    super.dispose();
  }

  void _cyclePlayerSkin() {
    setState(() {
      _playerSkinIndex = (_playerSkinIndex + 1) % _skins.length;
      _playerSkin = _skins[_playerSkinIndex];
      _slots[0] = {'name': 'YOU', 'skin': _playerSkin};
    });
  }

  @override
  Widget build(BuildContext context) {
    int joinedCount = _slots.where((s) => s != null).length;

    return Center(
      child: LiquidGlassDialog(
        width: 360,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'HAUNTED LOBBY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 24),

            // PREVIEW SELECTOR (Big)
            GestureDetector(
              onTap: _cyclePlayerSkin,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amberAccent, width: 2),
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  Image.asset(
                    'assets/images/game/characters/${_playerSkin}_front-32x48.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'TAP TO CHANGE SKIN',
              style: TextStyle(color: Colors.white38, fontSize: 9),
            ),

            const SizedBox(height: 32),
            Text(
              'Players: $joinedCount / 8',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // THE GRID: All 8 Players (including YOU)
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                itemCount: 8,
                itemBuilder: (context, index) {
                  final slot = _slots[index];
                  final isPlayer = index == 0;

                  return Container(
                    decoration: BoxDecoration(
                      color: isPlayer
                          ? Colors.amberAccent.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPlayer ? Colors.amberAccent : Colors.white10,
                        width: isPlayer ? 2 : 1,
                      ),
                    ),
                    child: slot == null
                        ? const Center(
                            child: SizedBox(
                              width: 12,
                              height: 12,
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
                                height: 35,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                slot['name']!,
                                style: TextStyle(
                                  color: isPlayer
                                      ? Colors.amberAccent
                                      : Colors.white54,
                                  fontSize: 7,
                                  fontWeight: isPlayer
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/services/economy/shop_manager.dart';
import 'package:dreamhunter/data/item_registry.dart';
import 'package:dreamhunter/widgets/game/character_selection_dialog.dart';
import 'package:dreamhunter/widgets/game/character_portrait.dart';

class LobbyPlayer {
  final String name;
  final String characterImage;
  final bool isHost;
  final bool isReady;

  LobbyPlayer({
    required this.name,
    required this.characterImage,
    this.isHost = false,
    this.isReady = false,
  });

  LobbyPlayer copyWith({bool? isReady}) {
    return LobbyPlayer(
      name: name,
      characterImage: characterImage,
      isHost: isHost,
      isReady: isReady ?? this.isReady,
    );
  }
}

class LobbyDialog extends StatefulWidget {
  final VoidCallback onStartGame;

  const LobbyDialog({super.key, required this.onStartGame});

  @override
  State<LobbyDialog> createState() => _LobbyDialogState();
}

class _LobbyDialogState extends State<LobbyDialog> {
  final List<LobbyPlayer?> _joinedPlayers = List.filled(6, null);
  final List<String> _pool = [
    'HunterX', 'SleepyHead', 'Nightmare_99', 'DreamWalker',
    'ZzzMaster', 'Insomniac', 'DarkSlayer', 'Lullaby',
    'GhostBuster', 'Midnight_Sun', 'DormGhost', 'ShadowMan'
  ];

  final List<String> _charPool = [
    'assets/images/game/characters/max_front-32x48.png',
    'assets/images/game/characters/nun_front-32x48.png',
    'assets/images/game/characters/jack_front-32x48.png',
  ];

  bool _isReady = false;
  int _countdown = 3;
  Timer? _joinTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _updateHostPlayer();
    _simulateMatchmaking();
  }

  void _updateHostPlayer() {
    final characterId = ShopManager.instance.selectedCharacterId;
    final character = ItemRegistry.get(characterId);
    setState(() {
      _joinedPlayers[0] = LobbyPlayer(
        name: 'You (Host)',
        characterImage: character?.image ?? _charPool[0],
        isHost: true,
        isReady: _isReady,
      );
    });
  }

  @override
  void dispose() {
    _joinTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _simulateMatchmaking() {
    if (_joinedPlayers.where((p) => p != null).length >= 6) return;

    final randomDelay = Random().nextInt(500);
    _joinTimer = Timer(Duration(milliseconds: randomDelay), () {
      if (!mounted || _isReady) return;
      
      setState(() {
        final firstEmptyIndex = _joinedPlayers.indexOf(null);
        if (firstEmptyIndex != -1) {
          final availablePool = _pool.where((name) => !_joinedPlayers.any((p) => p?.name == name)).toList();
          if (availablePool.isNotEmpty) {
            _joinedPlayers[firstEmptyIndex] = LobbyPlayer(
              name: availablePool[Random().nextInt(availablePool.length)],
              characterImage: _charPool[Random().nextInt(_charPool.length)],
              isReady: Random().nextBool(), // Randomly ready or not
            );
            HapticManager.instance.light();
          }
        }
      });
      
      _simulateMatchmaking();
    });
  }

  void _onActionButtonPressed() {
    if (_isReady) {
      _cancelCountdown();
    } else {
      _instantFillAndStart();
    }
  }

  void _instantFillAndStart() {
    setState(() {
      _isReady = true;
      _countdown = 3;
      // Host is now ready
      if (_joinedPlayers[0] != null) {
        _joinedPlayers[0] = _joinedPlayers[0]!.copyWith(isReady: true);
      }
      // Instant fill all empty slots and make everyone ready
      for (int i = 0; i < _joinedPlayers.length; i++) {
        if (_joinedPlayers[i] == null) {
          final availablePool = _pool.where((name) => !_joinedPlayers.any((p) => p?.name == name)).toList();
          if (availablePool.isNotEmpty) {
            _joinedPlayers[i] = LobbyPlayer(
              name: availablePool[Random().nextInt(availablePool.length)],
              characterImage: _charPool[Random().nextInt(_charPool.length)],
              isReady: true,
            );
          }
        } else {
          // Make existing players ready
          _joinedPlayers[i] = _joinedPlayers[i]!.copyWith(isReady: true);
        }
      }
    });

    _joinTimer?.cancel();
    _startCountdown();
  }

  void _cancelCountdown() {
    setState(() {
      _isReady = false;
      _countdown = 3;
      // Host is no longer ready
      if (_joinedPlayers[0] != null) {
        _joinedPlayers[0] = _joinedPlayers[0]!.copyWith(isReady: false);
      }
    });
    _countdownTimer?.cancel();
    _simulateMatchmaking();
    HapticManager.instance.light();
  }

  void _startCountdown() {
    HapticManager.instance.medium();
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      setState(() {
        if (_countdown > 1) {
          _countdown--;
          HapticManager.instance.light();
        } else {
          _countdownTimer?.cancel();
          Navigator.pop(context);
          widget.onStartGame();
        }
      });
    });
  }

  void _openCharacterSelection() {
    if (_isReady) return;
    
    showGeneralDialog(
      context: context,
      barrierLabel: "CharacterSelection",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: const CharacterSelectionDialog()),
        );
      },
    ).then((_) {
      if (mounted) _updateHostPlayer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ShopManager.instance,
      builder: (context, child) {
        final characterId = ShopManager.instance.selectedCharacterId;
        final character = ItemRegistry.get(characterId);
        final joinedCount = _joinedPlayers.where((p) => p != null).length;

        return Center(
          child: LiquidGlassDialog(
            width: 520,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GameDialogHeader(
                  title: 'LOBBY',
                  showCloseButton: !_isReady,
                  isCentered: true,
                ),
                const SizedBox(height: 8),
                Text(
                  '$joinedCount/6 HUNTERS JOINED',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.cyanAccent.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 20),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: GestureDetector(
                        onTap: _openCharacterSelection,
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Image.asset(
                                  character?.image ?? _charPool[0],
                                  height: 160,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.none,
                                ),
                              ),
                              Positioned(
                                bottom: 10, left: 0, right: 0,
                                child: Center(
                                  child: Text(
                                    _isReady ? 'STARTING...' : 'TAP TO SWITCH',
                                    style: TextStyle(
                                      color: Colors.cyanAccent.withValues(alpha: 0.5),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    
                    Expanded(
                      flex: 6,
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          final LobbyPlayer? player = _joinedPlayers[index];
                          final bool isFilled = player != null;
                          
                          return Container(
                            decoration: BoxDecoration(
                              color: isFilled 
                                  ? Colors.white.withValues(alpha: 0.1) 
                                  : Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isFilled 
                                    ? (player.isReady ? Colors.greenAccent : Colors.cyanAccent).withValues(alpha: 0.3) 
                                    : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: [
                                  if (isFilled)
                                    CharacterPortrait(
                                      imagePath: player.characterImage,
                                      size: 32,
                                    )
                                  else
                                    const Icon(Icons.person_outline, size: 24, color: Colors.white12),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          player?.name ?? '---',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: isFilled ? Colors.white : Colors.white24,
                                            fontWeight: isFilled ? FontWeight.bold : FontWeight.normal,
                                            letterSpacing: 0.5,
                                            fontSize: 10,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (isFilled)
                                          Text(
                                            player.isReady ? 'READY' : 'JOINING...',
                                            style: TextStyle(
                                              color: player.isReady ? Colors.greenAccent : Colors.white38,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                GlassButton(
                  label: _isReady ? 'CANCEL ($_countdown...)' : 'READY',
                  width: double.infinity,
                  height: 50,
                  borderRadius: 15,
                  glowColor: _isReady ? Colors.redAccent : Colors.tealAccent,
                  onTap: _onActionButtonPressed,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

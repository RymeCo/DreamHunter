import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/services/economy/shop_manager.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/data/item_registry.dart';
import 'package:dreamhunter/widgets/game/character_selection_dialog.dart';
import 'package:dreamhunter/widgets/game/character_portrait.dart';

class LobbyPlayer {
  final String name;
  final String characterImage;
  final bool isHost;
  final bool isReady;
  final bool isConnecting;

  LobbyPlayer({
    required this.name,
    required this.characterImage,
    this.isHost = false,
    this.isReady = false,
    this.isConnecting = false,
  });

  LobbyPlayer copyWith({bool? isReady, bool? isConnecting}) {
    return LobbyPlayer(
      name: name,
      characterImage: characterImage,
      isHost: isHost,
      isReady: isReady ?? this.isReady,
      isConnecting: isConnecting ?? this.isConnecting,
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
    'HunterX',
    'SleepyHead',
    'Nightmare_99',
    'DreamWalker',
    'ZzzMaster',
    'Insomniac',
    'DarkSlayer',
    'Lullaby',
    'GhostBuster',
    'Midnight_Sun',
    'DormGhost',
    'ShadowMan',
  ];

  final List<String> _charPool = [
    'assets/images/game/characters/max_front-32x48.png',
    'assets/images/game/characters/nun_front-32x48.png',
    'assets/images/game/characters/jack_front-32x48.png',
  ];

  bool _isReady = false;
  bool _isInstantStarting = false;
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
    if (_joinedPlayers.where((p) => p != null).length >= 6 || _isReady) return;

    // Faster join event (0.1s - 0.2s)
    final joinDelay = 100 + Random().nextInt(100);
    _joinTimer = Timer(Duration(milliseconds: joinDelay), () {
      if (!mounted || _isReady) return;

      setState(() {
        final emptyIndices = <int>[];
        for (int i = 0; i < _joinedPlayers.length; i++) {
          if (_joinedPlayers[i] == null) emptyIndices.add(i);
        }

        if (emptyIndices.isNotEmpty) {
          final targetIndex =
              emptyIndices[Random().nextInt(emptyIndices.length)];

          _joinedPlayers[targetIndex] = LobbyPlayer(
            name: 'Connecting...',
            characterImage: '',
            isConnecting: true,
          );
          HapticManager.instance.light();

          // Faster resolve connection (0.1s - 0.3s)
          final connectionDelay = 100 + Random().nextInt(200);
          Timer(Duration(milliseconds: connectionDelay), () {
            if (!mounted || _isReady || _joinedPlayers[targetIndex] == null) {
              return;
            }

            setState(() {
              final availableNames = _pool
                  .where((name) => !_joinedPlayers.any((p) => p?.name == name))
                  .toList();
              if (availableNames.isNotEmpty) {
                _joinedPlayers[targetIndex] = LobbyPlayer(
                  name: availableNames[Random().nextInt(availableNames.length)],
                  characterImage: _charPool[Random().nextInt(_charPool.length)],
                  isConnecting: false,
                  isReady: false,
                );
                HapticManager.instance.light();
              }
            });

            // Faster ready up (0.2s - 0.4s)
            final readyDelay = 200 + Random().nextInt(200);
            Timer(Duration(milliseconds: readyDelay), () {
              if (!mounted || _isReady || _joinedPlayers[targetIndex] == null) {
                return;
              }
              if (_joinedPlayers[targetIndex]!.isConnecting) return;

              setState(() {
                _joinedPlayers[targetIndex] = _joinedPlayers[targetIndex]!
                    .copyWith(isReady: true);
                HapticManager.instance.medium();
              });
            });
          });
        }
      });

      _simulateMatchmaking();
    });
  }

  void _onActionButtonPressed() {
    if (_isReady) {
      _cancelCountdown();
    } else {
      // Check if everyone else is already ready
      final aiPlayers = _joinedPlayers.sublist(1);
      final allAiReady = aiPlayers.every((p) => p != null && p.isReady);

      if (allAiReady) {
        _instantStart();
      } else {
        _instantFillAndStart();
      }
    }
  }

  void _instantStart() {
    _joinTimer?.cancel();
    HapticManager.instance.medium();

    setState(() {
      _isReady = true;
      _isInstantStarting = true;
      if (_joinedPlayers[0] != null) {
        _joinedPlayers[0] = _joinedPlayers[0]!.copyWith(isReady: true);
      }
    });

    Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      final aiSkins = _joinedPlayers
          .where((p) => p != null && !p.isHost)
          .map((p) => p!.characterImage)
          .toList();
      MatchManager.instance.setAISkins(aiSkins);

      Navigator.pop(context);
      widget.onStartGame();
    });
  }

  void _instantFillAndStart() {
    _joinTimer?.cancel();

    setState(() {
      _isReady = true;
      _countdown = 3;
      // Host readies up first
      if (_joinedPlayers[0] != null) {
        _joinedPlayers[0] = _joinedPlayers[0]!.copyWith(
          isReady: true,
          isConnecting: false,
        );
      }
    });

    // Start a periodic timer to rapidly fill and ready everyone else
    int index = 1;
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isReady) {
        timer.cancel();
        return;
      }

      if (index >= 6) {
        timer.cancel();
        _startCountdown();
        return;
      }

      setState(() {
        if (_joinedPlayers[index] == null ||
            _joinedPlayers[index]!.isConnecting) {
          final availablePool = _pool
              .where((name) => !_joinedPlayers.any((p) => p?.name == name))
              .toList();
          if (availablePool.isNotEmpty) {
            _joinedPlayers[index] = LobbyPlayer(
              name: availablePool[Random().nextInt(availablePool.length)],
              characterImage: _charPool[Random().nextInt(_charPool.length)],
              isReady: true,
              isConnecting: false,
            );
          }
        } else {
          _joinedPlayers[index] = _joinedPlayers[index]!.copyWith(
            isReady: true,
            isConnecting: false,
          );
        }
        HapticManager.instance.light();
      });

      index++;
    });
  }

  void _cancelCountdown() {
    setState(() {
      _isReady = false;
      _isInstantStarting = false;
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
          // Pass AI skins to MatchManager before starting
          final aiSkins = _joinedPlayers
              .where((p) => p != null && !p.isHost)
              .map((p) => p!.characterImage)
              .toList();
          MatchManager.instance.setAISkins(aiSkins);

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
          child: FadeTransition(
            opacity: animation,
            child: const CharacterSelectionDialog(),
          ),
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

        return StandardGlassPage(
          title: 'LOBBY',
          showCloseButton: !_isReady,
          isCentered: true,
          isCompact: true,
          width: 440,
          footer: [
            GlassButton(
              label: _isInstantStarting
                  ? 'STARTING...'
                  : (_isReady ? 'CANCEL ($_countdown...)' : 'READY'),
              width: double.infinity,
              height: 44,
              borderRadius: 12,
              glowColor: _isReady ? Colors.redAccent : Colors.tealAccent,
              onTap: _onActionButtonPressed,
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$joinedCount/6 HUNTERS JOINED',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.cyanAccent.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 8,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: GestureDetector(
                      onTap: _openCharacterSelection,
                      child: Container(
                        height: 130, // Even shorter
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Image.asset(
                                character?.image ?? _charPool[0],
                                height: 100, // Smaller image
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                            Positioned(
                              bottom: 6,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Text(
                                  _isReady ? 'READY!' : 'SWITCH',
                                  style: TextStyle(
                                    color: Colors.cyanAccent.withValues(
                                      alpha: 0.5,
                                    ),
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            childAspectRatio: 2.8,
                          ),
                      itemCount: 6,
                      itemBuilder: (context, index) {
                        final LobbyPlayer? player = _joinedPlayers[index];
                        final bool isFilled = player != null;
                        final bool isConnecting = player?.isConnecting ?? false;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: isFilled
                                ? (player.isReady
                                      ? Colors.greenAccent.withValues(
                                          alpha: 0.15,
                                        )
                                      : Colors.white.withValues(alpha: 0.1))
                                : Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFilled
                                  ? (player.isReady
                                            ? Colors.greenAccent
                                            : Colors.cyanAccent)
                                        .withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.05),
                              width: isFilled && player.isReady ? 1.5 : 1.0,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                if (isFilled && !isConnecting)
                                  CharacterPortrait(
                                    imagePath: player.characterImage,
                                    size: 32,
                                  )
                                else if (isConnecting)
                                  const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Center(
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.cyanAccent,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.person_outline,
                                    size: 24,
                                    color: Colors.white12,
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        child: Text(
                                          isConnecting
                                              ? 'LOADING...'
                                              : (player?.name ??
                                                    'SEARCHING...'),
                                          key: ValueKey(
                                            isConnecting
                                                ? 'loading'
                                                : (player?.name ?? 'searching'),
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: isFilled
                                                    ? Colors.white
                                                    : Colors.white24,
                                                fontWeight: isFilled
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                letterSpacing: 0.5,
                                                fontSize: 10,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isFilled)
                                        AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          child: Text(
                                            isConnecting
                                                ? 'CONNECTING'
                                                : (player.isReady
                                                      ? 'READY'
                                                      : 'WAITING...'),
                                            key: ValueKey(
                                              isConnecting
                                                  ? 'conn'
                                                  : (player.isReady
                                                        ? 'ready'
                                                        : 'wait'),
                                            ),
                                            style: TextStyle(
                                              color: player.isReady
                                                  ? Colors.greenAccent
                                                  : Colors.white38,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
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
            ],
          ),
        );
      },
    );
  }
}

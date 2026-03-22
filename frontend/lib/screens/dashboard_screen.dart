import 'package:dreamhunter/services/user_service.dart';
import 'package:dreamhunter/services/connectivity_service.dart';
import 'package:dreamhunter/services/backend_service.dart';
import 'package:dreamhunter/services/offline_cache.dart';
import 'package:dreamhunter/widgets/shop_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:dreamhunter/services/chat_service.dart';
import 'package:dreamhunter/widgets/clickable_image.dart';
import 'package:dreamhunter/widgets/login_dialog.dart';
import 'package:dreamhunter/widgets/register_dialog.dart';
import 'package:dreamhunter/widgets/profile_dialog.dart';
import 'package:dreamhunter/services/leveling_service.dart';
import 'package:dreamhunter/widgets/chat_dialog.dart';
import 'package:dreamhunter/widgets/leaderboard_dialog.dart';
import 'package:dreamhunter/widgets/daily_tasks_dialog.dart';
import 'package:dreamhunter/widgets/roulette_dialog.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/settings_dialog.dart';
import 'package:dreamhunter/widgets/game_widgets.dart';
import 'package:dreamhunter/services/backend_config.dart';
import 'package:dreamhunter/game/core/game_constants.dart';

enum AuthDialogType { login, register, profile }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late StreamSubscription<User?> _authStateSubscription;
  StreamSubscription<DocumentSnapshot>? _statsSubscription;
  Timer? _syncTimer;
  Timer? _playtimeTimer;
  bool _isLoggedIn = false;
  bool _isBackendReady = false;
  bool _hasUnclaimedTasks = false;
  Map<String, dynamic>? _cachedGlobalAlert;
  final Set<String> _notifiedTaskIds = {};
  AuthDialogType _currentDialogType = AuthDialogType.login;
  final UserService _userService = UserService();
  final BackendService _backendService = BackendService();

  @override
  void initState() {
    super.initState();
    ConnectivityService().initialize();
    _isLoggedIn = FirebaseAuth.instance.currentUser != null;
    _loadCachedData();
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() => _isLoggedIn = user != null);
        if (_isLoggedIn) {
          _startSyncTimer();
          _startPlaytimeTimer();
          _subscribeToUserStats();
        } else {
          _stopSyncTimer();
          _stopPlaytimeTimer();
          _statsSubscription?.cancel();
        }
      }
    });

    _pingBackend();
    if (_isLoggedIn) {
      _startSyncTimer();
      _startPlaytimeTimer();
      _subscribeToUserStats();
    }
  }

  void _startPlaytimeTimer() {
    _playtimeTimer?.cancel();
    _playtimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await OfflineCache.addTransaction(type: 'PLAYTIME', playtimeDelta: 60);
      _checkTaskCompletion();
    });
  }

  void _stopPlaytimeTimer() => _playtimeTimer?.cancel();

  Future<void> _checkTaskCompletion() async {
    final dailyTasks = await OfflineCache.getDailyTasks();
    if (dailyTasks == null || dailyTasks['tasks'] == null) return;

    bool foundUnclaimed = false;
    for (var task in (dailyTasks['tasks'] as List)) {
      final String id = task['id'];
      final bool isCompleted = (task['progress'] as num) >= (task['target'] as num);
      final bool isClaimed = task['claimed'] ?? false;

      if (isCompleted && !isClaimed) {
        foundUnclaimed = true;
        if (!_notifiedTaskIds.contains(id)) {
          _notifiedTaskIds.add(id);
          OfflineCache.saveNotifiedTaskIds(_notifiedTaskIds); // Persist
          if (mounted) {
            showCustomSnackBar(
              context,
              'TASK COMPLETED: ${task['title']}!',
              type: SnackBarType.success,
            );
          }
        }
      }
    }

    if (mounted && _hasUnclaimedTasks != foundUnclaimed) {
      setState(() => _hasUnclaimedTasks = foundUnclaimed);
    }
  }

  void _subscribeToUserStats() {
    _statsSubscription?.cancel();
    _statsSubscription = _userService.getUserStats().listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final queue = await OfflineCache.getTransactionQueue();
        if (queue.isEmpty) {
          final createdAtRaw = data['createdAt'];
          String? createdAtStr;
          if (createdAtRaw is Timestamp) {
            createdAtStr = createdAtRaw.toDate().toIso8601String();
          } else if (createdAtRaw is String) {
            createdAtStr = createdAtRaw;
          }

          await OfflineCache.saveCurrency(
            data['dreamCoins'] ?? 0,
            data['hellStones'] ?? 0,
            data['playtime'] ?? 0,
            data['freeSpins'] ?? 0,
            data['xp'] ?? 0,
            data['level'] ?? 1,
            data['avatarId'] ?? 0,
            createdAtStr,
            null, // dailyTasks are handled separately or if included in snapshot
            false, // forceUpdate = false for background cloud sync
          );
          _checkTaskCompletion();
        }
      }
    });

    ChatService().getGlobalAlert().listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        await OfflineCache.saveMetadata('global_alert', data);
        if (mounted) setState(() => _cachedGlobalAlert = data);
      } else {
        await OfflineCache.clearMetadata('global_alert');
        if (mounted) setState(() => _cachedGlobalAlert = null);
      }
    });
  }

  Future<void> _loadCachedData() async {
    final alert = await OfflineCache.getMetadata('global_alert');
    final notifiedIds = await OfflineCache.getNotifiedTaskIds();
    if (mounted) {
      setState(() {
        _cachedGlobalAlert = alert;
        _notifiedTaskIds.clear();
        _notifiedTaskIds.addAll(notifiedIds);
      });
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _reconcileEconomyWithBackend();
    });
    _reconcileEconomyWithBackend();
  }

  void _stopSyncTimer() => _syncTimer?.cancel();

  Future<void> _reconcileEconomyWithBackend() async {
    if (!_isLoggedIn || !_isBackendReady) return;
    try {
      final success = await _backendService.performFullSync();
      if (success && mounted) {
        _checkTaskCompletion();
        setState(() {});
      }
    } catch (e) {
      debugPrint('Background sync failed: $e');
    }
  }

  Future<void> _pingBackend() async {
    try {
      final response = await http
          .get(Uri.parse(BackendConfig.baseUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => _isBackendReady = true);
          if (_isLoggedIn) {
            _syncProfileWithBackend();
            _startSyncTimer();
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isBackendReady = false);
    }
  }

  Future<void> _syncProfileWithBackend() async {
    if (!_isLoggedIn || !_isBackendReady) return;
    await _backendService.performFullSync();
    await _userService.updateShopCache();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    _statsSubscription?.cancel();
    _stopSyncTimer();
    _stopPlaytimeTimer();
    super.dispose();
  }

  void _showGameDialog(Widget dialog) {
    showGeneralDialog(
      context: context,
      barrierLabel: "GameDialog",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: dialog),
        );
      },
    );
  }

  void _showDropdownMenu() {
    showGeneralDialog(
      context: context,
      barrierLabel: "DropdownMenu",
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: 100,
              right: 20,
              child: FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: animation,
                  alignment: Alignment.topRight,
                  child: LiquidGlassDialog(
                    width: 220,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMenuButton(
                          icon: Icons.assignment_rounded,
                          label: 'Daily Tasks',
                          showBadge: _hasUnclaimedTasks,
                          onTap: () {
                            Navigator.pop(context);
                            _showGameDialog(DailyTasksDialog(onTaskClaimed: _checkTaskCompletion));
                          },
                        ),
                        const Divider(color: Colors.white10),
                        _buildMenuButton(
                          icon: Icons.leaderboard_rounded,
                          label: 'Leaderboard',
                          onTap: () {
                            Navigator.pop(context);
                            _showGameDialog(LeaderboardDialog(backendService: _backendService));
                          },
                        ),
                        const Divider(color: Colors.white10),
                        _buildMenuButton(
                          icon: Icons.settings_rounded,
                          label: 'Settings',
                          onTap: () {
                            Navigator.pop(context);
                            _showGameDialog(SettingsDialog(
                              onLoginRequested: () {
                                Navigator.pop(context);
                                _showAuthDialog();
                              },
                            ));
                          },
                        ),
                        const Divider(color: Colors.white10),
                        _buildMenuButton(
                          icon: Icons.power_settings_new_rounded,
                          label: 'Exit Game',
                          onTap: () {
                            if (Platform.isAndroid || Platform.isIOS) {
                              SystemNavigator.pop();
                            } else {
                              exit(0);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: Colors.white70, size: 20),
                  if (showBadge)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuthDialog() {
    setState(() {
      _currentDialogType = _isLoggedIn ? AuthDialogType.profile : AuthDialogType.login;
    });

    showGeneralDialog(
      context: context,
      barrierLabel: "AuthDialog",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget dialogContent;
            const double dialogWidth = 350;
            const double dialogHeight = 600;
            const double logoHeight = 375;
            const double logoOverlap = 150;

            switch (_currentDialogType) {
              case AuthDialogType.login:
                dialogContent = LoginDialog(
                  onRegisterRequested: () => setDialogState(() => _currentDialogType = AuthDialogType.register),
                  onLoginSuccess: () {
                    setDialogState(() {
                      _isLoggedIn = true;
                      _currentDialogType = AuthDialogType.profile;
                    });
                    showCustomSnackBar(context, 'Welcome back!', type: SnackBarType.success);
                  },
                );
                break;
              case AuthDialogType.register:
                dialogContent = RegisterDialog(
                  onLoginRequested: () => setDialogState(() => _currentDialogType = AuthDialogType.login),
                  onRegisterSuccess: () {
                    setDialogState(() => _currentDialogType = AuthDialogType.login);
                    showCustomSnackBar(context, 'Account created! Please log in.', type: SnackBarType.success);
                  },
                );
                break;
              case AuthDialogType.profile:
                dialogContent = ProfileDialog(
                  backendService: _backendService,
                  onLogoutRequested: () => setDialogState(() {
                    _isLoggedIn = false;
                    _currentDialogType = AuthDialogType.login;
                  }),
                );
                break;
            }

            String logoPath = '';
            if (_currentDialogType == AuthDialogType.login) {
              logoPath = 'assets/images/auth/login_logo.png';
            } else if (_currentDialogType == AuthDialogType.register) {
              logoPath = 'assets/images/auth/register_logo.png';
            }

            final double dialogX = (MediaQuery.of(context).size.width - dialogWidth) / 2;
            final double dialogY = (MediaQuery.of(context).size.height - dialogHeight) / 2 + 100;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: dialogX,
                  top: dialogY,
                  child: SizedBox(
                    width: dialogWidth,
                    height: dialogHeight,
                    child: dialogContent,
                  ),
                ),
                if (logoPath.isNotEmpty)
                  Positioned(
                    left: dialogX + (dialogWidth - logoHeight) / 2,
                    top: dialogY - logoOverlap,
                    child: IgnorePointer(
                      child: Image.asset(logoPath, width: logoHeight, height: logoHeight, fit: BoxFit.contain),
                    ),
                  ),
              ],
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  void _showPurchaseDialog() {
    _showGameDialog(
      Center(
        child: LiquidGlassDialog(
          width: 350,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GameDialogHeader(title: 'Hell Stones', titleColor: Colors.redAccent),
              const SizedBox(height: 24),
              const Icon(Icons.diamond_rounded, color: Colors.redAccent, size: 80),
              const SizedBox(height: 16),
              const Text(
                'Purchase premium stones to unlock exclusive characters and items!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),
              GlassButton(
                onTap: () => Navigator.pop(context),
                label: 'BACK TO GAME',
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderColor: Colors.redAccent.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              const Text('(In-game purchases coming soon)', style: TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  void _convertCurrency() async {
    final Map<String, dynamic> currency = await OfflineCache.getCurrency();
    if ((currency['hellStones'] ?? 0) < 1) {
      if (mounted) showCustomSnackBar(context, 'Insufficient Hell Stones.', type: SnackBarType.error);
      return;
    }

    final int oldLevel = currency['level'] ?? 1;
    await OfflineCache.addTransaction(type: 'CONVERSION', dreamDelta: 100, hellDelta: -1);
    final Map<String, dynamic> newCurrency = await OfflineCache.getCurrency();
    final int newLevel = newCurrency['level'] ?? 1;

    if (mounted) {
      Navigator.pop(context);
      if (newLevel > oldLevel) {
        showCustomSnackBar(context, 'LEVEL UP! You are now Level $newLevel!', type: SnackBarType.success);
      } else {
        showCustomSnackBar(context, 'Successfully converted 1 Hell Stone! +50 XP', type: SnackBarType.success);
      }
    }
  }

  void _showCoinExchangeDialog() {
    _showGameDialog(
      Center(
        child: LiquidGlassDialog(
          width: 350,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GameDialogHeader(title: 'Exchange', titleColor: Colors.amberAccent),
              const SizedBox(height: 24),
              const Icon(Icons.toll_rounded, color: Colors.amberAccent, size: 80),
              const SizedBox(height: 16),
              const Text(
                'Exchange your premium Hell Stones for common Dream Coins!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),
              GlassButton(
                onTap: _convertCurrency,
                label: 'EXCHANGE NOW',
                color: Colors.amberAccent.withValues(alpha: 0.2),
                borderColor: Colors.amberAccent.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              const Text('(1 Hell Stone = 100 Dream Coins)', style: TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 100,
        leadingWidth: 300,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0),
          child: StreamBuilder<Map<String, dynamic>>(
            stream: Stream.periodic(const Duration(seconds: 1)).asyncMap((_) => OfflineCache.getCurrency()),
            builder: (context, snapshot) {
              final data = snapshot.data ?? {};
              final int coins = data['dreamCoins'] ?? 0;
              final int stones = data['hellStones'] ?? 0;
              final int xp = data['xp'] ?? 0;
              final int level = data['level'] ?? 1;
              final int avatarId = data['avatarId'] ?? 0;
              final double progress = LevelingService.getLevelProgress(xp);

              return Row(
                children: [
                  GestureDetector(
                    onTap: _showAuthDialog,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 2),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.black45,
                            backgroundImage: AssetImage(GameConstants.getAvatarPath(avatarId)),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: ValueListenableBuilder<bool>(
                              valueListenable: ConnectivityService().isOnline,
                              builder: (context, isOnline, child) {
                                return Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: isOnline ? Colors.greenAccent : Colors.redAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black, width: 2),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Lvl $level', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: GameProgressBar(percent: progress, height: 8)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildCurrencyChip(icon: Icons.toll_rounded, value: '$coins', color: Colors.amberAccent, onPlusTap: _showCoinExchangeDialog),
                        const SizedBox(height: 4),
                        _buildCurrencyChip(icon: Icons.diamond_rounded, value: '$stones', color: Colors.redAccent, onPlusTap: _showPurchaseDialog),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                GlassButton(
                  imagePath: 'assets/images/dashboard/sandwich.png',
                  width: 45,
                  height: 45,
                  onTap: _showDropdownMenu,
                ),
                if (_hasUnclaimedTasks)
                  Positioned(
                    top: 10,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/dashboard/main_background.png', fit: BoxFit.cover)),
          if (_cachedGlobalAlert != null && (_cachedGlobalAlert!['message'] as String).isNotEmpty)
            Positioned(
              top: 140,
              left: 20,
              right: 20,
              child: LiquidGlassDialog(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                color: Colors.redAccent.withValues(alpha: 0.6),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _cachedGlobalAlert!['message'] as String,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.15,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset('assets/images/game/environment/dorm.png', fit: BoxFit.contain, width: MediaQuery.of(context).size.width * 0.85),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: GlassButton(
              imagePath: 'assets/images/dashboard/roulette_man.png',
              width: 220,
              height: 220,
              onTap: () => _showGameDialog(RouletteDialog(onSpinCompleted: _checkTaskCompletion)),
            ),
          ),
          Positioned(
            bottom: -20,
            right: -20,
            child: GlassButton(
              imagePath: 'assets/images/dashboard/shop_stall.png',
              width: 220,
              height: 220,
              onTap: () => _showGameDialog(const ShopDialog()),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.19,
            left: 20,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GlassButton(
                  imagePath: 'assets/images/dashboard/signage.png',
                  width: 120,
                  height: 120,
                  onTap: () {
                    if (!_isBackendReady) {
                      showCustomSnackBar(context, 'Connecting to server...', type: SnackBarType.info);
                      _pingBackend();
                      return;
                    }
                    _showGameDialog(Center(child: ChatDialog(onMessageSent: _checkTaskCompletion)));
                  },
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyChip({required IconData icon, required String value, required Color color, VoidCallback? onPlusTap}) {
    return LiquidGlassDialog(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      borderRadius: 12,
      blurSigma: 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
          if (onPlusTap != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onPlusTap,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(Icons.add, color: color, size: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

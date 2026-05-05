import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Services
import 'package:dreamhunter/services/core/network_monitor.dart';
import 'package:dreamhunter/services/economy/wallet_manager.dart';
import 'package:dreamhunter/services/progression/daily_roulette.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';
import 'package:dreamhunter/services/identity/profile_manager.dart';
import 'package:dreamhunter/services/progression/progression_manager.dart';

// Widgets
import 'package:dreamhunter/widgets/dashboard/currency_display.dart';
import 'package:dreamhunter/widgets/dashboard/action_menu.dart';
import 'package:dreamhunter/widgets/dashboard/exchange_module.dart';
import 'package:dreamhunter/widgets/economy/shop_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/widgets/identity/auth_flow_dialog.dart';
import 'package:dreamhunter/widgets/community/chat_dialog.dart';
import 'package:dreamhunter/widgets/leaderboard_dialog.dart';
import 'package:dreamhunter/widgets/progression/daily_tasks_dialog.dart';
import 'package:dreamhunter/widgets/progression/roulette_dialog.dart';
import 'package:dreamhunter/widgets/settings_dialog.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/widgets/identity/save_resolution_dialog.dart';
import 'package:dreamhunter/widgets/game/lobby_dialog.dart';
import 'package:dreamhunter/services/economy/shop_manager.dart';
import 'package:dreamhunter/screens/game_loading_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late StreamSubscription<User?> _authStateSubscription;
  final WalletManager _controller = WalletManager.instance;
  bool _isLoggedIn = false;
  bool _showRelogNotice = false;

  @override
  void initState() {
    super.initState();
    unawaited(_backgroundInit());

    _isLoggedIn = FirebaseAuth.instance.currentUser != null;
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) {
      if (mounted) setState(() => _isLoggedIn = user != null);
    });
  }

  Future<void> _backgroundInit() async {
    AudioManager.instance.playDashboardMusic();
    await NetworkMonitor.instance.initialize();
    await _controller.initialize();
    await ProgressionManager.instance.initialize();
    await DailyRoulette.instance.initialize();

    // Check if we should show the relog notice
    final relogDismissed = await StorageEngine.instance.getMetadata('relog_notice_dismissed');
    if (relogDismissed == null) {
      setState(() => _showRelogNotice = true);
    }

    // Sync with live backend if logged in
    if (FirebaseAuth.instance.currentUser != null) {
      unawaited(ProfileManager.instance.syncWithBackend());
    }

    if (mounted && StorageEngine.instance.isConflictPending()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        unawaited(SaveResolutionDialog.showIfNeeded(context, user.uid));
      }
    }

    if (mounted) {
      final state = DailyRoulette.instance.state;
      if (state.isSpinning) {
        if (state.lastSpinWasPaid) {
          await _controller.updateBalance(
            coinsDelta: DailyRoulette.paidSpinCost,
          );
          if (mounted) {
            showCustomSnackBar(
              context,
              'RECOVERY: ${DailyRoulette.paidSpinCost} Coins refunded.',
              type: SnackBarType.info,
            );
          }
        } else {
          await DailyRoulette.instance.addFreeSpins(1);
          if (mounted) {
            showCustomSnackBar(
              context,
              'RECOVERY: 1 Free Spin restored.',
              type: SnackBarType.info,
            );
          }
        }
        await DailyRoulette.instance.setSpinning(false);
      }
    }
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _showGameDialog(Widget dialog) async {
    await showGeneralDialog(
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

  void _showAuthDialog() {
    _showGameDialog(
      AuthFlowDialog(
        initialIsLoggedIn: _isLoggedIn,
        onAuthStateChanged: (loggedIn) =>
            setState(() => _isLoggedIn = loggedIn),
      ),
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
                  child: DashboardActionMenu(
                    onDailyTasksTap: () {
                      Navigator.pop(context);
                      _showGameDialog(const DailyTasksDialog());
                    },
                    onLeaderboardTap: () {
                      Navigator.pop(context);
                      _showGameDialog(const LeaderboardDialog());
                    },
                    onSettingsTap: () {
                      Navigator.pop(context);
                      _showGameDialog(
                        SettingsDialog(
                          onLoginRequested: () {
                            Navigator.pop(context);
                            _showAuthDialog();
                          },
                        ),
                      );
                    },
                    onExitTap: () {
                      if (Platform.isAndroid || Platform.isIOS) {
                        SystemNavigator.pop();
                      } else {
                        exit(0);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildBackground(),
          _buildDormGraphic(),
          _buildPlayButton(),
          _buildRouletteButton(),
          _buildShopButton(),
          _buildChatButton(),
          if (_showRelogNotice) _buildRelogNotice(),
        ],
      ),
    );
  }

  // --- Sub-Widgets to simplify build() ---

  Widget _buildRelogNotice() {
    return Positioned(
      top: 120,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'SYSTEM: If you received a balance update or profile edit from an admin, please relog to sync your local wallet.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              IconButton(
                onPressed: () async {
                  setState(() => _showRelogNotice = false);
                  await StorageEngine.instance.saveMetadata(
                    'relog_notice_dismissed',
                    {'timestamp': DateTime.now().toIso8601String()},
                  );
                },
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 100,
      leadingWidth: 300,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 8.0),
        child: CurrencyDisplay(
          controller: _controller,
          onProfileTap: _showAuthDialog,
          onExchangeTap: () => _showGameDialog(
            ExchangeDialogContent(
              onBackTap: () => Navigator.pop(context),
              controller: _controller,
            ),
          ),
          onPurchaseTap: () => _showGameDialog(
            PurchaseDialogContent(onBackTap: () => Navigator.pop(context)),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: GlassButton(
            width: 51,
            height: 51,
            padding: const EdgeInsets.all(3),
            pulseMinOpacity: 0.7,
            onTap: _showDropdownMenu,
            child: OverflowBox(
              minWidth: 45,
              maxWidth: 45,
              minHeight: 45,
              maxHeight: 45,
              child: Image.asset(
                'assets/images/dashboard/sandwich.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Image.asset(
        'assets/images/dashboard/main_background.png',
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildDormGraphic() {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.15,
      left: 0,
      right: 0,
      child: Center(
        child: Image.asset(
          'assets/images/dashboard/core/dorm.png',
          fit: BoxFit.contain,
          width: MediaQuery.of(context).size.width * 0.85,
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.18,
      left: 0,
      right: 0,
      child: Center(
        child: GlassButton(
          label: 'PLAY',
          width: 140,
          height: 49,
          borderRadius: 25,
          glowColor: Colors.tealAccent,
          hoverColor: Colors.tealAccent.withValues(alpha: 0.15),
          hoverBorderColor: Colors.tealAccent,
          hoverTextColor: Colors.tealAccent,
          pulseMinOpacity: 0.5,
          onTap: () {
            _showGameDialog(
              LobbyDialog(
                onStartGame: () {
                  final characterId = ShopManager.instance.selectedCharacterId;
                  // Map 'char_max' -> 'max', 'char_nun' -> 'nun', etc for the loading screen
                  final type = characterId.replaceFirst('char_', '');

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          GameLoadingScreen(characterType: type),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRouletteButton() {
    return Positioned(
      bottom: 10,
      left: 10,
      child: _buildDashboardIconButton(
        assetPath: 'assets/images/dashboard/roulette_man.png',
        glowColor: Colors.pinkAccent,
        onTap: () => _showGameDialog(
          RouletteDialog(controller: _controller, parentContext: context),
        ),
      ),
    );
  }

  Widget _buildShopButton() {
    return Positioned(
      bottom: 10,
      right: 10,
      child: _buildDashboardIconButton(
        assetPath: 'assets/images/dashboard/shop_stall.png',
        glowColor: Colors.amberAccent,
        width: 157,
        height: 162,
        padding: const EdgeInsets.only(left: 5, top: 5, right: 5, bottom: 10),
        onTap: () => _showGameDialog(ShopDialog(controller: _controller)),
      ),
    );
  }

  Widget _buildChatButton() {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.22,
      left: 15,
      child: _buildDashboardIconButton(
        assetPath: 'assets/images/dashboard/signage.png',
        glowColor: Colors.cyanAccent,
        width: 76,
        height: 102,
        overflowSize: 102,
        borderRadius: 17,
        onTap: () {
          if (!_isLoggedIn) {
            showCustomSnackBar(
              context,
              'Please login to access the global chat.',
              type: SnackBarType.info,
            );
            _showAuthDialog();
          } else {
            _showGameDialog(const Center(child: ChatDialog()));
          }
        },
      ),
    );
  }

  Widget _buildDashboardIconButton({
    required String assetPath,
    required Color glowColor,
    required VoidCallback onTap,
    double width = 148,
    double height = 148,
    double overflowSize = 204,
    EdgeInsets? padding,
    double borderRadius = 28,
  }) {
    return GlassButton(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(5),
      borderRadius: borderRadius,
      glowColor: glowColor,
      hoverColor: glowColor.withValues(alpha: 0.15),
      hoverBorderColor: glowColor,
      pulseMinOpacity: 0.3,
      onTap: onTap,
      child: OverflowBox(
        alignment: const Alignment(0, -0.07),
        minWidth: overflowSize,
        maxWidth: overflowSize,
        minHeight: overflowSize,
        maxHeight: overflowSize,
        child: Image.asset(assetPath, fit: BoxFit.contain),
      ),
    );
  }
}

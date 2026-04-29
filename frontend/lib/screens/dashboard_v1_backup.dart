import 'package:dreamhunter/services/core/network_monitor.dart';
import 'package:dreamhunter/services/economy/wallet_manager.dart';
import 'package:dreamhunter/services/progression/daily_roulette.dart';
import 'package:dreamhunter/widgets/dashboard/currency_display.dart';
import 'package:dreamhunter/widgets/dashboard/action_menu.dart';
import 'package:dreamhunter/widgets/dashboard/exchange_module.dart';
import 'package:dreamhunter/widgets/economy/shop_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dreamhunter/widgets/identity/login_dialog.dart';
import 'package:dreamhunter/widgets/identity/register_dialog.dart';
import 'package:dreamhunter/widgets/identity/profile_dialog.dart';
import 'package:dreamhunter/widgets/community/chat_dialog.dart';
import 'package:dreamhunter/widgets/leaderboard_dialog.dart';
import 'package:dreamhunter/widgets/progression/daily_tasks_dialog.dart';
import 'package:dreamhunter/widgets/progression/roulette_dialog.dart';
import 'package:dreamhunter/widgets/settings_dialog.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/widgets/identity/save_resolution_dialog.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';

enum AuthDialogType { login, register, profile }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late StreamSubscription<User?> _authStateSubscription;
  final WalletManager _controller = WalletManager.instance;
  bool _isLoggedIn = false;
  AuthDialogType _currentDialogType = AuthDialogType.login;

  @override
  void initState() {
    super.initState();
    // DETACH HEAVY INITIALIZATION: Run in background to avoid blocking splash/dashboard transition
    unawaited(_backgroundInit());

    _isLoggedIn = FirebaseAuth.instance.currentUser != null;
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) {
      if (mounted) {
        setState(() => _isLoggedIn = user != null);
      }
    });
  }

  Future<void> _backgroundInit() async {
    // 1. Start music immediately
    AudioManager.instance.playDashboardMusic();

    // 2. Initialize background services
    await NetworkMonitor.instance.initialize();
    await _controller.initialize();
    await DailyRoulette.instance.initialize();

    // 3. Handle Save Conflict Recovery (Crash/Close protection)
    if (mounted && StorageEngine.instance.isConflictPending()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        unawaited(SaveResolutionDialog.showIfNeeded(context, user.uid));
      }
    }

    // 4. Handle Crash Refunds (Economy Logic Fix)
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
    // Note: Refresh is automatic now via Singleton + ListenableBuilder
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

  void _showAuthDialog() {
    setState(() {
      _currentDialogType = _isLoggedIn
          ? AuthDialogType.profile
          : AuthDialogType.login;
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

            switch (_currentDialogType) {
              case AuthDialogType.login:
                dialogContent = LoginDialog(
                  onRegisterRequested: () => setDialogState(
                    () => _currentDialogType = AuthDialogType.register,
                  ),
                  onLoginSuccess: () {
                    setDialogState(() {
                      _isLoggedIn = true;
                      _currentDialogType = AuthDialogType.profile;
                    });
                    showCustomSnackBar(
                      context,
                      'Welcome back!',
                      type: SnackBarType.success,
                    );
                  },
                );
                break;
              case AuthDialogType.register:
                dialogContent = RegisterDialog(
                  onLoginRequested: () => setDialogState(
                    () => _currentDialogType = AuthDialogType.login,
                  ),
                  onRegisterSuccess: () {
                    setDialogState(
                      () => _currentDialogType = AuthDialogType.login,
                    );
                    showCustomSnackBar(
                      context,
                      'Account created! Please log in.',
                      type: SnackBarType.success,
                    );
                  },
                );
                break;
              case AuthDialogType.profile:
                dialogContent = ProfileDialog(
                  onLogoutRequested: () => setDialogState(() {
                    _isLoggedIn = false;
                    _currentDialogType = AuthDialogType.login;
                  }),
                );
                break;
            }

            final double dialogX =
                (MediaQuery.of(context).size.width - dialogWidth) / 2;
            final double dialogY =
                (MediaQuery.of(context).size.height - dialogHeight) / 2 + 100;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
              width: 51, // 45 (icon) + 3 (left) + 3 (right) = 51
              height: 51,
              padding: const EdgeInsets.all(3), // 3px margin as requested
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
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/dashboard/main_background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
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
          ),
          Positioned(
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
                onTap: () {},
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: GlassButton(
              width: 148,
              height: 148,
              padding: const EdgeInsets.all(5),
              borderRadius: 28,
              glowColor: Colors.pinkAccent,
              hoverColor: Colors.pinkAccent.withValues(alpha: 0.15),
              hoverBorderColor: Colors.pinkAccent,
              pulseMinOpacity: 0.3,
              onTap: () => _showGameDialog(
                RouletteDialog(controller: _controller, parentContext: context),
              ),
              child: OverflowBox(
                alignment: const Alignment(0, -0.07), // Subtle pull UP
                minWidth: 204,
                maxWidth: 204,
                minHeight: 204,
                maxHeight: 204,
                child: Image.asset(
                  'assets/images/dashboard/roulette_man.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: GlassButton(
              width: 157,
              height:
                  162, // Increased height to accommodate extra bottom padding
              padding: const EdgeInsets.only(
                left: 5,
                top: 5,
                right: 5,
                bottom: 10,
              ), // 10px at bottom
              borderRadius: 28,
              glowColor: Colors.amberAccent,
              hoverColor: Colors.amberAccent.withValues(alpha: 0.15),
              hoverBorderColor: Colors.amberAccent,
              pulseMinOpacity: 0.3,
              onTap: () => _showGameDialog(ShopDialog(controller: _controller)),
              child: OverflowBox(
                alignment: const Alignment(0, -0.07),
                minWidth: 204,
                maxWidth: 204,
                minHeight: 204,
                maxHeight: 204,
                child: Image.asset(
                  'assets/images/dashboard/shop_stall.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.22,
            left: 15,
            child: GlassButton(
              width: 76,
              height: 102,
              padding: const EdgeInsets.all(5),
              borderRadius: 17,
              glowColor: Colors.cyanAccent,
              hoverColor: Colors.cyanAccent.withValues(alpha: 0.15),
              hoverBorderColor: Colors.cyanAccent,
              pulseMinOpacity: 0.3,
              onTap: () => _showGameDialog(const Center(child: ChatDialog())),
              child: OverflowBox(
                alignment: const Alignment(0, -0.07), // Subtle pull UP
                minWidth: 102,
                maxWidth: 102,
                minHeight: 102,
                maxHeight: 102,
                child: Image.asset(
                  'assets/images/dashboard/signage.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

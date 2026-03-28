import 'package:dreamhunter/services/connectivity_service.dart';
import 'package:dreamhunter/services/dashboard_controller.dart';
import 'package:dreamhunter/services/roulette_service.dart';
import 'package:dreamhunter/widgets/dashboard/currency_display.dart';
import 'package:dreamhunter/widgets/dashboard/action_menu.dart';
import 'package:dreamhunter/widgets/dashboard/exchange_module.dart';
import 'package:dreamhunter/widgets/shop_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dreamhunter/widgets/login_dialog.dart';
import 'package:dreamhunter/widgets/register_dialog.dart';
import 'package:dreamhunter/widgets/profile_dialog.dart';
import 'package:dreamhunter/widgets/chat_dialog.dart';
import 'package:dreamhunter/widgets/leaderboard_dialog.dart';
import 'package:dreamhunter/widgets/daily_tasks_dialog.dart';
import 'package:dreamhunter/widgets/roulette_dialog.dart';
import 'package:dreamhunter/screens/game_loading_screen.dart';
import 'dart:developer' as developer;
import 'package:dreamhunter/widgets/settings_dialog.dart';
import 'package:dreamhunter/widgets/clickable_image.dart';

enum AuthDialogType { login, register, profile }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late StreamSubscription<User?> _authStateSubscription;
  final DashboardController _controller = DashboardController();
  bool _isLoggedIn = false;
  AuthDialogType _currentDialogType = AuthDialogType.login;

  @override
  void initState() {
    super.initState();
    ConnectivityService().initialize();
    _controller.initialize();
    _checkPendingRouletteRewards();
    _isLoggedIn = FirebaseAuth.instance.currentUser != null;
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() => _isLoggedIn = user != null);
      }
    });
  }

  Future<void> _checkPendingRouletteRewards() async {
    // Wait for the controller to be initialized properly
    await Future.delayed(const Duration(milliseconds: 500));
    
    final state = await RouletteService.getAndSyncState();
    
    if (state.pendingReward != null) {
      if (state.isSpinning && state.spinStartTime != null) {
        // BACKGROUND SPIN LOGIC:
        // Calculate how much longer we need to wait
        final startTime = DateTime.parse(state.spinStartTime!);
        final now = DateTime.now();
        final elapsed = now.difference(startTime);
        const totalDuration = Duration(seconds: 5);

        if (elapsed < totalDuration) {
          final remaining = totalDuration - elapsed;
          developer.log('Spin is active in background. Waiting ${remaining.inSeconds}s...', name: 'DashboardScreen');
          await Future.delayed(remaining);
        }
      }

      // Re-fetch state to see if it was already claimed by the Dialog (if user reopened it)
      final finalState = await RouletteService.getAndSyncState();
      if (finalState.pendingReward != null) {
        final reward = finalState.pendingReward!;
        final amount = (reward['amount'] as num).toInt();
        final name = reward['name'] as String;

        await _controller.updateCurrency(
          newCoins: _controller.dreamCoins + amount,
        );
        await RouletteService.clearPendingReward();
        await RouletteService.setSpinning(false);

        if (mounted) {
          showCustomSnackBar(
            context,
            'Background spin finished! You received: $name',
            type: SnackBarType.success,
          );
        }
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
    _controller.refreshCurrency();
    _checkPendingRouletteRewards(); // Check if a spin was left running
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
                      _showGameDialog(SettingsDialog(
                        onLoginRequested: () {
                          Navigator.pop(context);
                          _showAuthDialog();
                        },
                      ));
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
                  onLogoutRequested: () => setDialogState(() {
                    _isLoggedIn = false;
                    _currentDialogType = AuthDialogType.login;
                  }),
                );
                break;
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
            onExchangeTap: () => _showGameDialog(ExchangeDialogContent(
              onBackTap: () => Navigator.pop(context),
              controller: _controller,
            )),
            onPurchaseTap: () => _showGameDialog(PurchaseDialogContent(onBackTap: () => Navigator.pop(context))),
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
          Positioned.fill(child: Image.asset('assets/images/dashboard/main_background.png', fit: BoxFit.cover)),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.15,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset('assets/images/game/environment/dorm.png', fit: BoxFit.contain, width: MediaQuery.of(context).size.width * 0.85),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.45,
            left: 0,
            right: 0,
            child: Center(
              child: GlassButton(
                label: 'PLAY',
                width: 200,
                height: 70,
                borderRadius: 35,
                glowColor: Colors.deepPurpleAccent,
                pulseMinOpacity: 0.5,
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const GameLoadingScreen()),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: GlassButton(
              width: 175,
              height: 175,
              padding: const EdgeInsets.all(6),
              borderRadius: 32,
              pulseMinOpacity: 0.3,
              onTap: () => _showGameDialog(RouletteDialog(
                controller: _controller,
                parentContext: context,
                onSpinCompleted: () => _controller.refreshCurrency(),
              )),
              child: OverflowBox(
                alignment: const Alignment(0, -0.07), // Subtle pull UP
                minWidth: 240,
                maxWidth: 240,
                minHeight: 240,
                maxHeight: 240,
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
              width: 185,
              height: 191, // Increased height to accommodate extra bottom padding
              padding: const EdgeInsets.only(left: 6, top: 6, right: 6, bottom: 12), // 12px at bottom
              borderRadius: 32,
              pulseMinOpacity: 0.3,
              onTap: () => _showGameDialog(ShopDialog(controller: _controller)),
              child: OverflowBox(
                alignment: const Alignment(0, -0.07),
                minWidth: 240,
                maxWidth: 240,
                minHeight: 240,
                maxHeight: 240,
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
              width: 90,
              height: 120,
              padding: const EdgeInsets.all(6),
              borderRadius: 20,
              pulseMinOpacity: 0.3,
              onTap: () => _showGameDialog(const Center(child: ChatDialog())),
              child: OverflowBox(
                alignment: const Alignment(0, -0.07), // Subtle pull UP
                minWidth: 120,
                maxWidth: 120,
                minHeight: 120,
                maxHeight: 120,
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
